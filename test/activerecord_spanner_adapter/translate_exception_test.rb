# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "test_helper"

class TranslateExceptionTest < TestHelper::MockActiveRecordTest
  attr_reader :adapter

  def setup
    super
    @adapter = ActiveRecord::ConnectionAdapters::SpannerAdapter.new(connection)
  end

  def test_translate_already_exists_error_to_record_not_unique
    spanner_message = "Table my_sample_table: Row {Int64(9999)} already exists."
    exception = Google::Cloud::AlreadyExistsError.new(spanner_message)
    message = "Google::Cloud::AlreadyExistsError: #{spanner_message}"
    sql = "COMMIT"
    binds = []

    result = adapter.send(
      :translate_exception, exception, message: message, sql: sql, binds: binds
    )

    assert_kind_of ActiveRecord::RecordNotUnique, result
    assert_equal message, result.message
    assert_equal sql, result.sql
    assert_equal binds, result.binds
  end

  def test_translate_already_exists_error_with_unrecognized_message
    exception = Google::Cloud::AlreadyExistsError.new("Some other database error")
    message = "Google::Cloud::AlreadyExistsError: Some other database error"
    sql = "UPDATE `singers` SET `first_name` = @p1 WHERE `singers`.`id` = @p2"
    binds = []

    result = adapter.send(
      :translate_exception, exception, message: message, sql: sql, binds: binds
    )

    assert_kind_of ActiveRecord::StatementInvalid, result
    refute_kind_of ActiveRecord::RecordNotUnique, result
  end

  def test_translate_exception_class_wraps_already_exists_as_record_not_unique
    spanner_message = "Table my_sample_table: Row {Int64(9999)} already exists."
    exception = Google::Cloud::AlreadyExistsError.new(spanner_message)
    sql = "COMMIT"
    binds = []

    result = adapter.send(:translate_exception_class, exception, sql, binds)

    assert_kind_of ActiveRecord::RecordNotUnique, result
    assert_equal exception.backtrace, result.backtrace if exception.backtrace
  end

  def test_translate_failed_precondition_not_null_violation
    spanner_message = "Column `name` must not be NULL."
    exception = Google::Cloud::FailedPreconditionError.new(spanner_message)
    message = "Google::Cloud::FailedPreconditionError: #{spanner_message}"
    sql = "INSERT INTO `singers` (`first_name`) VALUES (@p1)"
    binds = []

    result = adapter.send(
      :translate_exception, exception, message: message, sql: sql, binds: binds
    )

    assert_kind_of ActiveRecord::NotNullViolation, result
  end
end
