require 'i18n'
require 'ostruct'
require 'active_model'
require 'active_record'
require 'active_support'

require 'active_support/core_ext/date/acts_like'
require 'active_support/core_ext/time/zones'
require 'active_record/connection_adapters/postgresql_adapter'

require 'torque/postgresql/config'
require 'torque/postgresql/version'
require 'torque/postgresql/collector'

require 'torque/postgresql/associations'
require 'torque/postgresql/autosave_association'
require 'torque/postgresql/reflection'
require 'torque/postgresql/base' # Needs to be after inheritance

require 'torque/postgresql/railtie' if defined?(Rails)
