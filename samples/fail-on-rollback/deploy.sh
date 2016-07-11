bundle install --path vendor/bundle

echo "Create the initial stack - this should succeed"
bundle exec cf_deploy deploy dev base -f ./cf_deployer.yml -i WebServerPort:8000 || (echo "The first deploy should have succeeded.  This test failed due to failing pre-conditions."; exit 1)
if [ $? != 0 ]; then bundle exec cf_deploy destroy dev base -f ./cf_deployer.yml; exit 1; fi

echo "\nMake a change that will trigger a failure and rollback (eg: port 0 is not a valid port)"
bundle exec cf_deploy deploy dev base -f ./cf_deployer.yml -i WebServerPort:0 && (echo "The deployment should have been rolled back and returned a non-zero status.  This test failed, rollbacks are being reported as success."; exit 0)
if [ $? = 0 ]; then bundle exec cf_deploy destroy dev base -f ./cf_deployer.yml; exit 1; fi

echo "\nStack is now in UPDATE_ROLLBACK_COMPLETE.  Do a deploy with no changes - it should succeed."
bundle exec cf_deploy deploy dev base -f ./cf_deployer.yml -i WebServerPort:8000 || (echo "Deployments with no changes in UPDATE_ROLLBACK_COMPLETE should succeed.  This test failed."; exit 1)
if [ $? != 0 ]; then bundle exec cf_deploy destroy dev base -f ./cf_deployer.yml; exit 1; fi

echo "\nAll Tests Passed!"

echo "\nCleaning up environment"
bundle exec cf_deploy destroy dev base -f ./cf_deployer.yml
