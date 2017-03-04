### The main goal of this fork is to make the plugin more compatible with other plugins that allow to add time entries in other means that the standard log time page.  
#### This fork removes the need to associate a time log with a contract when the time log is added.  This is controlled by a setting, which defaults to false.  Go to the plugin settings page to enable this feature.

### Current changes in this fork:

- The time log entries do not need to be associated to a contract.  They will go in the first contract that covers the time log date range, according to the following logic:
 - The time log goes into the oldest contract having start and end dates matching the time log date.  If many contracts in the project do overlap, the oldest one will prevail.
 - It is possible to manually assign time log entries to specific project, even if the date is before or after the contract.  You can do this by right-clicking any time log entry, either in the log time details page, or in any contract view showing the log time entries.
 - Time entries that are not associated manually and do not fall in the range of any contract are displayed in some default (virtual) contracts.
 - When a time log is created, a message will show into which contract, if any, this time log is currently visible.
- Invoices can be added to contracts (in a very similar way to expenses).
 - **NOTE: This creates a new table named 'contracts_invoices'**
- Some UI improvements:
 - More responsive layout
 - Better alignment
 - Right-mouse click in time entries list in the contract view

------------

A Redmine plugin for managing the time/money being spent on client contracts.

This plugin allows you to: 

- Create and store client contracts
- Visualize how much time/money has been spent on a particular contract
- Associate time entries with specific contracts

### Special thanks to [UpgradeYa](http://www.upgradeya.com) for funding this project. 

Installation
------------ 
Option  1 - Download zip

1. Download the zip (for Redmine 2 you will need to download the v1.3.1 zip from the github releases page)
1. Unzip the redmine-contracts-with-time-tracking-plugin-master folder, rename it to contracts, and place it in the redmine plugins folder.
1. run 'rake redmine:plugins:migrate RAILS_ENV=production' from your redmine root directory

Option 2 - Git clone

1. Run 'git clone https://github.com/upgradeya/redmine-contracts-with-time-tracking-plugin.git plugins/contracts' from your redmine root directory
  * Note : use 'git submodule add' instead of 'git clone' if your install folder is part of a git project.
1. This step is only for Redmine 2 - After you run the git command above, cd into the contracts directory and run 'git checkout tags/v1.3.1'
1. run 'rake redmine:plugins:migrate RAILS_ENV=production' from your redmine root directory

Screenshots
-----------

### View all contracts for a project:
![view contracts for project](https://github.com/bsyzek/redmine-contracts-with-time-tracking-plugin/raw/master/docs/screenshots/multiple_contracts.png)

### View contract details:
![view contract details](https://github.com/bsyzek/redmine-contracts-with-time-tracking-plugin/raw/master/docs/screenshots/single_contract.png)

### Create and edit contracts:
![create and edit contracts](https://github.com/bsyzek/redmine-contracts-with-time-tracking-plugin/raw/master/docs/screenshots/edit_contract.png)

### Set permisisons:
![manage permissions](https://github.com/bsyzek/redmine-contracts-with-time-tracking-plugin/raw/master/docs/screenshots/permissions.png)

Changelog
---------
Contracts v2.2 2017-2-7
-----------------------
- Added a 'Fixed Price' contract type that calculates your effective rate and hides hourly information from your client (in permissions uncheck 'View spent time ').
- Added a summary tab that shows the cumulative time spent on each issue within that contract.
- Fixed the no confirmation for deletion bug.

Contracts v2.1 2016-3-5
-----------------------
- Renamed the expenses database table name to prevent conflicts with other redmine plugins

Contracts v2.0 2016-1-9
-----------------------
- Contracts plugin is now Redmine 3 compatible

Contracts v1.3.1, 2015-12-27
----------------------------
- Implemented new feature to lock contracts. This can be used to prevent old contracts and their time entries from accidentally being edited.
- Locked contracts are hidden from new time entry dropdowns
- Implementing caching on locked contracts to decrease load time on the contract pages.

Contracts v1.2.0, 2015-12-14
----------------------------
- On contract form the fields are now inline and date fields use calendar widget. Required fields are now marked. Any validations will re-populate the screen with previous data.
- Adding a time entry selects last created contract. Used to use start and end date. For sub-projects it selects the last created contract within the sub-project if a contract exists. Also fixed for expenses. Currently there is no way to add expense in sub-project to the parent contract if there are no sub-project contracts.
- New Agreement Pending - (basically just not marking that field as required) Agreed on date shows agreement pending on contract list and detail page. Date range is not shown when agreement is pending.
- If they have auto-contract creation enabled, a time entry that exceeds the remaining contract will auto-create a new contract and submit a time entry to the new contract with the remaining time.
- Discussion on the title. Fixed title format. Auto-increments based on all the projects IDs. Need to add a per project identifier so the auto-increment is project based and not entire redmine based.
