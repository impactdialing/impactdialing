STRIPE_SECRET_KEY      = ENV['STRIPE_SECRET_KEY']
STRIPE_PUBLISHABLE_KEY = ENV['STRIPE_PUBLISHABLE_KEY']
Stripe.api_key         = STRIPE_SECRET_KEY
SUBSCRIPTION_PLANS     = YAML.load_file(File.join(Rails.root, "/config/subscription_plans.yml"))
