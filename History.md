## 0.3.0 / 2015-05-21

### 3 major enhancements:

  * Process each message in a separate controller instance (`BaseController::Dispatcher` introduced)
  * Use separate channels and work pools per controller
  * ControllerManager#start selectively starts controllers
  
### 7 minor enhancements:

  * `queue` & `queue_exists?` methods for TestRabbitConnection
  * Single reply queue per rabbit connection
  * configuration_store removed from `RabbitClient` (should be used separately)
  * `RabbitConnection.logger` default set to `ServiceBase.logger`
  * ActiveRecordConnectionCleaner - a middleware for active connection cleanup
  * ServiceBase.application with middlewares introduced
  * Network failure recovery rewritten (using automatic bunny recovery with additional reply queue binding recovery)
  
### 1 bug fix:

  * `RabbitConnection` logger setup with configuration

## 0.2.0 / 2015-05-08

### 1 major enhancement:

  * `RabbitConnection` connection cache. `RabbitConnection.open(configuration_name)` as a standard connection access method.

### 11 minor enhancements:

  * BaseController callbacks around :start and :setup
  * Public BaseController#setup method (for manual routing control in tests)
  * ServiceBase::BaseClient tests, expect_published helper method
  * ServiceBase::Message required_attributes and optional_attributes declarations
  * ServiceBase::ServiceCache caches the store object with method: ServiceBase::ServiceCache.store
  * ServiceBase::BaseClient singleton methods accept any number of arguments (passed to constructor)
  * Get rid of ClientProxy. Error handling unified in BaseClient.
  * Default logger for BaseClient (ServiceBase.logger)
  * ServiceBase::Message validation callbacks
  * ServiceBase::Message#ignore_excess_attributes for open messages
  * assert_published accepts block and yields message
  
## 0.1.7 / 2015-04-01

### 1 minor enhancement:

  * ServiceBase::BaseClient introduced (with MessageHandler and SyncMessageHandler)
  
## 0.1.6 / 2015-03-02

### 1 bug fix:

  * Protect RabbitConnection from crash when Rails.root is not set
  
## 0.1.5 / 2015-02-06

### 2 minor enhancement:

  * Test fix: timeout raised
  * Rails 4.2 compatibility fix

## 0.1.4 / 2014-11-17

### 1 minor enhancement:

  * Switched to minitest

### 1 bug fix:

  * Blocking client proxy should not block on immediate reply (refs #13829)

## 0.1.3 / 2014-10-28

### 1 minor enhancement:

  * Remove Rails dependencies

## 0.1.2 / 2014-10-10

### 4 minor enhancements:

  * Update corrupted gemspec
  * Move add_engine_migrations method to hoe-puzzleflow
  * User always PuzzleFlow gem server
  * User always PuzzleFlow gem server
  * rakefile cleaning

## 0.1.1 / 2014-09-30

### 1 major enhancement:

  * hoe introduced with git and geminabox integration

### 1 minor enhancements:

  * do not show ruby warnings (reset RUBY_FLAGS)
  * hoe-puzzleflow used to unify hoe spec with other PuzzleFlow gems

## 0.1.0 / 2014-09-29

### 1 major enhancement

  * Birthday!



