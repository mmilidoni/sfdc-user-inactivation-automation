# Salesforce - User Freezing and Inactivation Automation

This tool automatically freezes and inactivates Salesforce users.

Features:
* you can define the number of days after the last login date a user will get frozen;
* you can define the number of days after the last login date a user will get inactivated;
* a notification email will be sent with the list of users frozen and inactivated;
* the report `Users by Login Date` will be available after installing the package. You can subscribe it to monitor the users that are going to be frozen/inactivated;
* you can whitelist the users that will never be frozen/inactivated by this automation;
* you can exclude the profiles that will never be frozen/inactivated by this automation;   
* for security reasons, all users with `System Administrator` profile will be automatically excluded by this automation.

Please visit [https://github.com/mmilidoni/sfdc-user-inactivation-automation/wiki](WIKI Page) to see how to install and configure the package.
