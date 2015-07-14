## 0.4.0 / 2015-07-10

  * Remove ActiveSupport dependencies (use Facets if Rails not loaded)
  * Replace ActiveSupport::Cache with MiniCache and fix validation tests
  * Use RabbitConnection#on_return method with all exchanges
  * YARD introduced
  * Tochtli::SimpleValidation for validation error messages
  * RabbitClient#rabbit_config removed
  * Removed RabbitClient#publish_and_wait (use SyncMessageHandler
  * Fix #2: Client error on dropped message
  * No more automatic routing. All routes have to be defined in the controller. (got rid of the MessageMap)
  * Message attributes rewritten with Virtus.
  * Message#bind_topic renamed to route_to
  * BaseController#subscribe renamed to bind
  * BaseClient#instance (singleton support) removed
  * Tochtli::Test::IntegrationHelpers module with methods extracted from Tochtli::Test::Integration
  * setup and teardown -> before_setup and after_teardown (no need for def setup; super; ... in tests)
  
## 0.3.0 / 2015-05-21

### 4 major enhancements:

  * Process each message in a separate controller instance (`BaseController::Dispatcher` introduced)
  * Use separate channels and work pools per controller
  * ControllerManager#start selectively starts controllers
  * BaseController#start accepts queue name. Multiple queues are supported per single controller.
  
### 8 minor enhancements:

  * `queue` & `queue_exists?` methods for TestRabbitConnection
  * Single reply queue per rabbit connection
  * configuration_store removed from `RabbitClient` (should be used separately)
  * `RabbitConnection.logger` default set to `Tochtli.logger`
  * ActiveRecordConnectionCleaner - a middleware for active connection cleanup
  * Tochtli.application with middlewares introduced
  * Network failure recovery rewritten (using automatic bunny recovery with additional reply queue binding recovery)
  * Bunny logger redirected to RabbitConnection logger with level dependent on Tochtli.debug_bunny (by default WARN)
  
### 1 bug fix:

  * `RabbitConnection` logger setup with configuration

## 0.2.0 / 2015-05-08

### 1 major enhancement:

  * `RabbitConnection` connection cache. `RabbitConnection.open(configuration_name)` as a standard connection access method.

### 11 minor enhancements:

  * BaseController callbacks around :start and :setup
  * Public BaseController#setup method (for manual routing control in tests)
  * Tochtli::BaseClient tests, expect_published helper method
  * Tochtli::Message required_attributes and optional_attributes declarations
  * Tochtli::ServiceCache caches the store object with method: Tochtli::ServiceCache.store
  * Tochtli::BaseClient singleton methods accept any number of arguments (passed to constructor)
  * Get rid of ClientProxy. Error handling unified in BaseClient.
  * Default logger for BaseClient (Tochtli.logger)
  * Tochtli::Message validation callbacks
  * Tochtli::Message#ignore_excess_attributes for open messages
  * assert_published accepts block and yields message
  
## 0.1.7 / 2015-04-01

### 1 minor enhancement:

  * Tochtli::BaseClient introduced (with MessageHandler and SyncMessageHandler)
  
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



