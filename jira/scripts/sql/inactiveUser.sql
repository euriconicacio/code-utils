 SELECT cwd_user.user_name, cwd_user.email_address, from_unixtime(round(cwd_user_attributes.attribute_value/1000)) FROM cwd_user, cwd_user_attributes WHERE cwd_user_attributes.user_id = cwd_user.id AND cwd_user_attributes.attribute_name = 'login.lastLoginMillis' AND from_unixtime(round(cwd_user_attributes.attribute_value/1000)) < CURDATE()-INTERVAL 31 DAY AND cwd_user.active = '1' INTO OUTFILE '/tmp/inactive_jira_user_$(date +%F).csv';

