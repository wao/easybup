$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'easybup'

require 'minitest/autorun'
require 'minitest/reporters'
require 'shoulda/context'

require 'mocha/mini_test'

Minitest::Reporters.use! Minitest::Reporters::SpecReporter. new # spec-like progress
