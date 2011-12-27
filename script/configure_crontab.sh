TMPFILE=$(mktemp -t cron.XXX)
echo "0 0 * * * export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin && cd $2/current && /usr/local/bin/bundle exec rake -f $2/current/Rakefile update_twilio_stats RAILS_ENV=$1 >> $2/current/log/cron_jobs.log 2>&1" >> $TMPFILE
crontab -r
crontab $TMPFILE 
crontab -l
rm $TMPFILE
echo "Crontab added!"

