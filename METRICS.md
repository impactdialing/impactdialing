# App metrics

## Auto-scaling

### Background Workers

1. *Churn* Frequent requests to modify number of background workers can slow things down by increasing runtime duration of jobs while each performs scaling request in after perform hooks.
  - `autoscale.processname.total`
  - `autoscale.processname.error`
  - `autoscale.processname.up`
  - `autoscale.processname.down`
1. *Jobs* Spikes in the number of certain jobs run can indicate systemic or user-induced issues.
  - `processname.jobs`
  - `processname.jobname.jobs`

# Call Rate metrics

## Predictive

## Power

## Preview