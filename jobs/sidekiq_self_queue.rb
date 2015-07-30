module SidekiqSelfQueue
  def add_to_queue(*job_args)
    Sidekiq::Client.push({
      'queue' => 'call_flow',
      'class' => self,
      'args'  => [*job_args]
    })
  end
end
