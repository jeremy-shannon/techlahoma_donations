class Subscription < ActiveRecord::Base

  include GuidIds

  validates :email, :presence => true

  def donor_name
    self.accept_recognition? ? name : "An Anonymous Donor"
  end
  # Ideally the process of charging a card would happen
  # in the bakground and in a service object of some sort.
  # This is the quick and dirty method that doesn't require background workers.
  before_create :charge_the_token, :populate_plan_data
  after_create :send_thank_you_email, :notify_slack, :notify_techlahomies
  def charge_the_token
    customer = Stripe::Customer.create(
      :source => self.token_id,
      :plan => self.stripe_plan_id,
      :email => self.email
    )
    self.stripe_customer_id = customer["id"]
    self.stripe_subscription_id = customer["subscriptions"]["data"].first["id"]
    self.stripe_status = customer["subscriptions"]["data"].first["status"]
    self.stripe_response = customer.to_json
    #self.save!
  end

  def populate_plan_data
    self.plan_name = plan[:name]
    self.interval = plan[:interval]
    self.interval_count = plan[:interval_count]
  end

  def cancel
    customer = Stripe::Customer.retrieve(stripe_customer_id)
    customer.subscriptions.retrieve(stripe_subscription_id).delete
    self.stripe_status = 'canceled'
    self.save
  end

  def canceled?
    stripe_status == 'canceled'
  end

  def send_thank_you_email
    SubscriptionMailer.thank_you_email(self).deliver_later
  end

  def notify_slack
    Chat.slack_message("New Subscription: $#{self.amount.to_i} by #{self.email}")
  end

  def notify_techlahomies
    #p 'email techlahoma@gmail.com about subscription posting'
  end

  def plan
    Plan.find_by_stripe_id(stripe_plan_id)
  end

end
