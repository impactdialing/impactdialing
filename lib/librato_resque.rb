require 'active_support/core_ext/string/inflections'
require 'impact_platform/metrics'

##
# Print metrics to STDOUT for now (take advantage of Heroku+Librato log drain integration).
# Submitting directly to librato api requires integrating librato-metrics
# and will impact job performance a bit more than printing to STDOUT
# since any collected metrics must be submitted before the job completes.
module LibratoResque
  def source(extra=nil)
    [ENV['LIBRATO_SOURCE'], @queue, self.to_s.split('::').last.underscore, extra].compact.join('.')
  end

  def after_perform(*job_args)
    ImpactPlatform::Metrics.count('resque.completed', 1, source)
  end

  def on_failure(exception, *job_args)
    extra = exception.class.to_s.split('::').last.underscore
    ImpactPlatform::Metrics.count('resque.exception', 1, source(extra))
  end

  def around_perform(*job_args)
    a = Time.now.to_f
    yield
    b = Time.now.to_f
    d = (b - a)
    ImpactPlatform::Metrics.measure('resque.worker.time', d, source)
  end
end
