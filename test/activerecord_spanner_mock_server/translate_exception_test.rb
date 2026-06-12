# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.
#
# frozen_string_literal: true

require_relative "./base_spanner_mock_server_test"

module MockServerTests
  class TranslateExceptionTest < BaseSpannerMockServerTest
    def test_already_exists_is_translated_to_record_not_unique
      insert_sql = register_insert_singer_result
      already_exists_error = GRPC::BadStatus.new(
        GRPC::Core::StatusCodes::ALREADY_EXISTS,
        "Table singers: Row {Int64(9999)} already exists."
      )
      # Push the same error twice, as the first statement in a transaction is retried once
      # after an explicit BeginTransaction RPC.
      @mock.push_error insert_sql, already_exists_error
      @mock.push_error insert_sql, already_exists_error

      err = assert_raises ActiveRecord::RecordNotUnique do
        ActiveRecord::Base.transaction do
          Singer.create first_name: "Dave", last_name: "Allison"
        end
      end

      assert_match(/already exists/, err.message)
      assert_equal insert_sql, err.sql
    end

    def test_already_exists_with_unrecognized_message_is_statement_invalid
      insert_sql = register_insert_singer_result
      already_exists_error = GRPC::BadStatus.new(
        GRPC::Core::StatusCodes::ALREADY_EXISTS,
        "Some other database error"
      )
      # Push the same error twice, as the first statement in a transaction is retried once
      # after an explicit BeginTransaction RPC.
      @mock.push_error insert_sql, already_exists_error
      @mock.push_error insert_sql, already_exists_error

      err = assert_raises ActiveRecord::StatementInvalid do
        ActiveRecord::Base.transaction do
          Singer.create first_name: "Dave", last_name: "Allison"
        end
      end

      refute_kind_of ActiveRecord::RecordNotUnique, err
      assert_kind_of Google::Cloud::AlreadyExistsError, err.cause
      assert_equal insert_sql, err.sql
    end

    def test_failed_precondition_not_null_is_translated_to_not_null_violation
      insert_sql = register_insert_singer_result
      not_null_error = GRPC::BadStatus.new(
        GRPC::Core::StatusCodes::FAILED_PRECONDITION,
        "Column `first_name` must not be NULL."
      )
      @mock.push_error insert_sql, not_null_error
      @mock.push_error insert_sql, not_null_error

      err = assert_raises ActiveRecord::NotNullViolation do
        ActiveRecord::Base.transaction do
          Singer.create first_name: "Dave", last_name: "Allison"
        end
      end

      assert_match(/must not be NULL/, err.message)
      assert_equal insert_sql, err.sql
    end

    private

    def register_insert_singer_result
      sql = "INSERT INTO `singers` (`first_name`, `last_name`, `id`) VALUES (@p1, @p2, @p3)"
      @mock.put_statement_result sql, StatementResult.new(1)
      sql
    end
  end
end
