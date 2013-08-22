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

### Contributing

Master is mainline development and should always be ready to deploy.

Work on features, bugs, etc should be done on topical branches. When ready push branch up and open a pull request.

Once the pull request is merged, delete the branch and carry on.