TMPFILE=$(mktemp -t cron.XXX)
echo "*/1 * * * * cd $2/current &&  rake update_twilio_stats RAILS_ENV=$1 " >> $TMPFILE
crontab -r
crontab $TMPFILE 
crontab -l
rm $TMPFILE
echo "Crontab added!"

