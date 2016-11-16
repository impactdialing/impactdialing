HireFire::Resource.configure do |config|
  auto_scaling_queues = [
    :reports, :general, :dial_queue, :billing,
    :dialer_worker, :simulator_worker, :import
  ]

  auto_scaling_queues.each do |queue_name|
    config.dyno(queue_name) do
      HireFire::Macro::Resque.queue(queue_name)
    end
  end
end
