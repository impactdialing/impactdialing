## Impact Dialing

### Installing

Install MySQL.

Make sure to disable `STRICT_TRANS_TABLES` sql_mode for MySQL. Locate & update `my.cnf` w/ following.

```
sql_mode=NO_ENGINE_SUBSTITUTION #,STRICT_TRANS_TABLES
```

Restart MySQL.

Install Redis.

Install rvm and proper ruby version (see /.ruby-version).

### Running Specs

Start Redis: `redis-server`.

`rake spec`

### Running Dev Server

Start web & worker processes: `foreman start`.

### Deployment

Jeremiah: `do you keep parity between aws and heroku at all times?`

Nikhil: `i generally do 3 deploys to prod. 2 heroku and 1 aws`

Deploy to EC2: `bundle exec cap (aws|aws_staging) deploy`

Deploy to Heroku: `heroku push local-branch remote-branch`

### Servers & Environments

#### Staging

##### EC2

ssh user: `root`

deploy user: `impactdialing`

- Redis-Staging
- Haproxy-Impact
- App1 Stage

##### Heroku

- impactdialing-staging
  - web
      - 1 unicorn
  - workers
      - 1 call\_flow
      - 1 upload\_download
- status-impactdialing
  - web
      - 1 unicorn

#### Production

##### EC2

ssh user: `ubuntu`

deploy user: `impactdialing`

- Redis-production
- Haproxy Prod
- LTS1
- LTS2

##### Heroku

- impactkungfupushupsclient
  - web
      - 2 unicorn
  - workers
      - 1 background\_worker
      - 2 call\_flow
      - 1 clock
      - 1 dialer\_loop
      - 1 dialer\_worker
      - 1 persist\_worker
      - 1 simulator\_loop
      - 1 simulator\_worker
      - 1 twilio\_stats
      - 1 upload\_download

- impactcallergiraffeblue
  - web
    - 2 unicorn

### Contributing

Master is mainline development and should always be ready to deploy.

Work on features, bugs, etc should be done on topical branches. When ready push branch up and open a pull request.

Once the pull request is merged, delete the branch and carry on.
