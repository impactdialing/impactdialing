Wolverine.config.instrumentation = Proc.new{|script_name, runtime, eval_type|
  ImpactPlatform::Metrics.print("measure##{script_name}.#{eval_type}=#{runtime}")
}
