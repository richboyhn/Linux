#!/bin/bash
token='823087038:AAH6sxp7yx5fSGw-LuayTVEiKQF-VUrT_oU'
chatid='-402099484'
function f_sendmail()
{
  curl --data chat_id=$chatid --data-urlencode "text=$msg" "https://api.telegram.org/bot$token/sendMessage" &> /dev/null
}
check()
{
    OVER_QUOTA=$(sed -n "/$(date --date="10 minutes ago" "+%d-%H:%M")/,\$p" /opt/zimbra/log/cbpolicyd.log | grep -oP '.*from=\K([a-zA-Z0-9.-]+@[a-zA-Z0-9.]+)(?=.*(quota_match))' | uniq)
}
check
if [ -n "$OVER_QUOTA" ]; then
su - zimbra -c "zmprov ma $OVER_QUOTA zimbraAccountStatus closed"
su - zimbra -c "zmprov sp $OVER_QUOTA Bkns@@1234"
msg="email dang spam: $OVER_QUOTA"
f_sendmail
fi