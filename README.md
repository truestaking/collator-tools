# collator-tools

## See current success rate ##

  my_current_block_success.sh 

-- runs on the active collator, queries /var/log/syslog for "prepared block" entries, then checks the chain for successful authorship.

## See success rates for all collators over a round ##

  moonbeam_round_success.sh 

-- runs on backup or primary collator, uses journalctl to pull out just the log entries we want, identifies both primary block chances and secondary block chances. Assumes you are running the service from systemd with name of moonbeam.service .

1) Add these two log lines in the parachain portion of your moonbeam.service file:

  --log rpc=info \\
  --tracing-targets author-filter=debug \

2) you must install jq and bc (you will be prompted if you have not installed these utilities)

3) systemctl daemon-reload ; systemctl restart moonbeam.service

Now you **MUST** wait until we have logs for a complete round. Anything less than a full round of logs will simply generate error messages and inaccurate results.  So if you enable logging in round X, you must wait until round x+1 is completed. Then you can view the success rates for round x+1.

Usage moonbeam_round_success.sh <round#>

Be patient, it can take 1-2 minutes to complete as we must query the chain for block authorship of all 1,800 blocks in the round…

**NOTES**: We make some assumptions about the logs, the key one is that "eligible author" statements are relative to the immediately following "imported BLOCK" statements. The first such occurrence in the logs for BLOCK X identifies the primary author of BLOCK X. Subsequent eligible/import statements for BLOCK X will indicate repeated attempts by the primary author OR the preset secondary authors for BLOCK X. We have limited visibility to this -- but the numbers work out, the assumptions seem correct when compared to our own collator events and it appears to be accurate -- use at your own risk and please notify us of any issues you encounter.

