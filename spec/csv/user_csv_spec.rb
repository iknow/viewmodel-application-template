# frozen_string_literal: true

require 'rails_helper'

# Includes several test cases that serve primarily to test the (abstract)
# ApplicationCsv behaviour.
RSpec.describe UserCsv do
  include ViewModelHelper
  include CsvHelper
  subject { UserCsv.new }

  let_factory(:user)

  let(:column_expectations) { simple_column_expectations }

  let(:simple_column_expectations) do
    {
      id: user.id,
      email: user.email,
      name: user.name,
      interface_language: ParamSerializers::Language.dump(user.interface_language),
      created_at: csv_time(user.created_at),
      updated_at: csv_time(user.updated_at),
    }
  end

  let(:dynamic_column_expectations) do
    {
      example1: 'example1 value',
      example2: 'example2 value',
    }
  end

  let(:aggregate_column_expectations) do
    {
      total_abilities: Ability.values.size.to_s,
    }
  end

  # Proxy test for ApplicationCsv
  describe '#serialize_template' do
    let(:writable_column_names) do
      column_names - ['created_at', 'updated_at']
    end

    it 'serializes the column names' do
      result_file = subject.serialize_template(writable_column_names, request_filters:, language: Language::EN)
      consume_bom!(result_file)
      table = CSV.new(result_file, headers: true).read
      expect(table.headers).to eq(writable_column_names)
    end
  end

  describe '#serialize' do
    include_examples 'serializes the column expectations'

    context 'with dynamic columns' do
      let(:column_expectations) do
        simple_column_expectations.merge(dynamic_column_expectations)
      end

      include_examples 'serializes the column expectations'
    end

    context 'with aggregate columns' do
      let(:column_expectations) do
        simple_column_expectations.merge(aggregate_column_expectations)
      end

      include_examples 'serializes the column expectations'
    end

    # Proxy test for ApplicationCsv
    context 'with unknown columns' do
      let(:column_expectations) do
        super().merge(invalid: 'incorrect')
      end
      it 'raises an error' do
        expect { serialize }.to raise_error(ApplicationCsv::InvalidColumns) do |err|
          expect(err.columns).to contain_exactly('invalid')
        end
      end
    end

    # Proxy test for ApplicationCsv
    context 'in another timezone' do
      let(:timezone) { ParamSerializers::Timezone.load('America/Los_Angeles') }
      include_examples 'serializes the column expectations'
    end

    # Proxy test for ApplicationCsv
    context 'with locking' do
      let(:lock) { true }
      include_examples 'serializes the column expectations'
    end

    # Proxy test for ApplicationCsv
    context 'with limits' do
      let(:limit) { 1 }
      include_examples 'serializes the column expectations'

      context 'with more results than the limit' do
        let_factory(:other_user, :user) { { id: '00000000-0000-0000-0000-000000000103' } }

        let(:column_expectations) do
          { id: other_user.id }
        end

        let(:expected_truncated) { true }
        # asserts that there is only one row in the response (and that it matches the expectations)
        include_examples 'serializes the column expectations'
      end
    end

    # Proxy test for ApplicationCsv
    context 'with non-permissive access control' do
      # everything is forbidden
      let(:vm_access_control) { ViewModel::AccessControl.new }

      it 'violates the access control' do
        expect { serialize }.to raise_error(ViewModel::AccessControlError)
      end
    end
  end

  # Proxy test for ApplicationCsv
  describe '#serialize_viewmodels' do
    let(:viewmodel) { UserView.new(user) }

    def serialize
      result_file = subject.serialize_viewmodels(
        [viewmodel], column_names,
        request_filters:, lock:, timezone:, aggregate_range:, serialize_context: vm_serialize_context)

      consume_bom!(result_file)

      # mimic a serialize() result including rows and truncation
      [result_file, 1, false]
    end

    include_examples 'serializes the column expectations'
  end

  describe '#deserialize' do
    context 'creating' do
      let(:user) { nil }

      let(:email) { 'another_user@example.com' }
      let(:interface_language) { Language::JA }

      let(:request_columns) do
        {
          id: '',
          email:,
          interface_language: interface_language.code,
        }
      end

      let(:expected_result_columns) do
        request_columns.keys.map(&:to_s)
      end

      it 'deserializes to a new user' do
        results, result_columns = deserialize_csv

        expect(result_columns).to eq(expected_result_columns)

        expect(results.length).to eq(1)
        user = results.first.model

        expect(user).to be_previously_new_record
        expect(user.email).to eq(email)
        expect(user.interface_language).to eq(interface_language)
      end

      # Proxy test for ApplicationCsv
      context 'with a invalidly escaped csv header' do
        def dump_to_csv(_request_columns)
          csv = Tempfile.new
          csv.unlink
          csv.write("a,\"b,c\n")
          csv.rewind
          csv
        end

        it 'rejects' do
          expect { deserialize_csv }.to raise_error(ApplicationCsv::InvalidCsv) do |err|
            expect(err).to have_attributes(
                             causes: contain_exactly(
                               be_kind_of(ApplicationCsv::MalformedRow)))
          end
        end
      end

      # Proxy test for ApplicationCsv
      context 'with a invalidly escaped csv row' do
        def dump_to_csv(request_columns)
          csv = super
          csv.seek(0, IO::SEEK_END)
          csv.write("a,\"b,c\n")
          csv.rewind
          csv
        end

        it 'rejects' do
          expect { deserialize_csv }.to raise_error(ApplicationCsv::InvalidCsv) do |err|
            expect(err).to have_attributes(
                             causes: contain_exactly(
                               be_kind_of(ApplicationCsv::MalformedRow)))
          end
        end
      end

      # Proxy test for ApplicationCsv
      context 'with an invalid format column' do
        let(:request_columns) { super().merge(interface_language: 'busted') }
        it 'rejects' do
          expect { deserialize_csv }.to raise_error(ApplicationCsv::InvalidCsv) do |err|
            expect(err).to match_a_row_error(
                             1,
                             be_kind_of(ApplicationCsv::ColumnFormatError) &
                             have_attributes(column: :interface_language, value: 'busted'))
          end
        end
      end

      # Proxy test for ApplicationCsv
      context 'with a validation failure' do
        let(:email) { 'cheese' }
        it 'rejects' do
          expect { deserialize_csv }.to raise_error(ApplicationCsv::InvalidCsv) do |err|
            expect(err).to match_a_row_error(1, be_kind_of(ViewModel::DeserializationError::Validation))
          end
        end
      end

      # Proxy test for ApplicationCsv
      context 'with a non-writable column' do
        let(:request_columns) { super().merge(updated_at: '2020-01-01') }
        it 'rejects' do
          expect { deserialize_csv }.to raise_error(ApplicationCsv::ReadOnlyColumns) do |err|
            expect(err.columns).to contain_exactly('updated_at')
          end
        end
      end
    end

    context 'updating' do
      let(:request_columns) do
        {
          id: user.id,
        }
      end

      it 'can make an empty update' do
        deserialize_update
      end

      # Proxy tests for ApplicationCsv
      context 'with a read-only access control' do
        let(:vm_access_control) { ViewModel::AccessControl::ReadOnly.new }

        context 'with a column change' do
          let(:request_columns) { super().merge(interface_language: Language::JA.enum_constant) }

          it 'violates the access control' do
            expect { deserialize_update }.to raise_error(ViewModel::AccessControlError)
          end
        end

        context 'with a column nullify' do
          let(:request_columns) { super().merge(name: 'remove_value') }
          it 'violates the access control' do
            expect { deserialize_update }.to raise_error(ViewModel::AccessControlError)
          end
        end

        context 'with an empty update' do
          it 'makes no change to violate the access control' do
            deserialize_update
          end
        end

        context 'with an empty string column' do
          let(:request_columns) { super().merge(name: '') }
          it 'makes no change to violate the access control' do
            deserialize_update
          end
        end
      end

      context 'updating column' do
        context 'email' do
          let(:new_email) { 'updated@example.com' }

          let(:request_columns) do
            super().merge(email: new_email)
          end

          it 'makes the update' do
            result = deserialize_update
            expect(result.email).to eq(new_email)
          end

          # Proxy test for ApplicationCsv
          context 'with an illegal value' do
            let(:request_columns) do
              super().merge(interface_language: 'busted')
            end
            it 'raises an error' do
              expect { deserialize_csv }.to raise_error(ApplicationCsv::InvalidCsv) do |err|
                expect(err).to match_a_row_error(
                                 1,
                                 be_kind_of(ApplicationCsv::ColumnFormatError) &
                                 have_attributes(column: :interface_language, value: 'busted'))
              end
            end
          end
        end
      end
    end
  end
end
