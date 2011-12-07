TMPFILE=$(mktemp -t cron.XXX)
echo "*/1 * * * * cd $2/current && /usr/local/bin/bundle exec rake -f $2/current/Rakefile update_twilio_stats RAILS_ENV=$1 >> $2/current/log/cron_jobs.log " >> $TMPFILE
crontab -r
crontab $TMPFILE 
crontab -l
rm $TMPFILE
echo "Crontab added!"

