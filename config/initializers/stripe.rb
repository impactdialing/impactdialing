Stripe.api_key = STRIPE_SECRET_KEY

SUBSCRIPTION_PLANS = YAML.load_file(File.join(Rails.root, "/config/subscription_plans.yml"))
