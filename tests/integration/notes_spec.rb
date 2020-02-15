
require './lib/faexport'
require_relative 'check_helper'

require 'rspec'

describe 'FA parser home page endpoint' do

  before do
    config = File.exist?('settings-test.yml') ? YAML.load_file('settings-test.yml') : {}
    @app = FAExport::Application.new(config).instance_variable_get(:@instance)
    @fa = @app.instance_variable_get(:@fa)
    @fa.login_cookie = COOKIE_DEFAULT
  end

  after do
    # Do nothing
  end

  context 'folders' do
    it 'can list inbox' do
      @fa.login_cookie = COOKIE_TEST_USER_2
      notes = @fa.notes('inbox')

      expect(notes).not_to be_empty

      notes.map do |note|
        expect(note[:note_id]).to be_instance_of Integer
        expect(note[:note_id]).not_to be_blank
        expect(note[:subject]).to be_instance_of String
        expect(note[:subject]).not_to be_blank
        expect(note[:is_inbound]).to eql(true)
        expect(note[:is_read]).to be_in([true, false])
        expect(note[:profile]).not_to eql(TEST_USER_2)
        expect(note).to have_valid_profile_link
        expect(note[:posted]).to be_valid_date_and_match_iso(note[:posted_at])
      end
    end

    it 'can list unread, which contains all unread notes from inbox' do
      @fa.login_cookie = COOKIE_TEST_USER_2
      unread_notes = @fa.notes('unread')
      inbox_notes = @fa.notes('inbox')

      expect(unread_notes).not_to be_empty

      unread_notes.map do |note|
        expect(note[:is_read]).to eql(false)
      end

      unread_note_ids = unread_notes.map{|n| n[:note_id]}
      inbox_note_ids = inbox_notes.select{|n| !n[:is_read]}.map{|n| n[:note_id]}

      inbox_note_ids.map do |note_id|
        expect(note_id).to be_in(unread_note_ids)
      end
    end

    it 'can list outbox and handle unread outbound notes' do
      @fa.login_cookie = COOKIE_TEST_USER_2
      notes = @fa.notes('outbox')

      expect(notes).not_to be_empty

      notes.map do |note|
        expect(note[:note_id]).to be_instance_of Integer
        expect(note[:note_id]).not_to be_blank
        expect(note[:subject]).to be_instance_of String
        expect(note[:subject]).not_to be_blank
        expect(note[:is_inbound]).to eql(false)
        expect(note[:is_read]).to be_in([true, false])
        expect(note[:profile]).not_to eql(TEST_USER_2)
        expect(note).to have_valid_profile_link
        expect(note[:posted]).to be_valid_date_and_match_iso(note[:posted_at])
      end
    end

    it 'can list other folders' do
      @fa.login_cookie = COOKIE_TEST_USER_2
      %w(high medium low archive trash).map do |folder|
        notes = @fa.notes(folder)

        expect(notes).not_to be_empty

        notes.map do |note|
          expect(note[:note_id]).to be_instance_of Integer
          expect(note[:note_id]).not_to be_blank
          expect(note[:subject]).to be_instance_of String
          expect(note[:subject]).not_to be_blank
          expect(note[:is_inbound]).to be_in([true, false])
          expect(note[:is_read]).to be_in([true, false])
          expect(note[:profile]).not_to eql(TEST_USER_2)
          expect(note).to have_valid_profile_link
          expect(note[:posted]).to be_valid_date_and_match_iso(note[:posted_at])
        end
      end
    end
  end

  context 'individual notes' do
    it 'can view a specific note' do
      @fa.login_cookie = COOKIE_TEST_USER_2
      note = @fa.note(108710830)

      expect(note[:note_id]).to be_instance_of Integer
      expect(note[:note_id]).not_to be_blank
      expect(note[:subject]).to be_instance_of String
      expect(note[:subject]).not_to be_blank
      expect(note[:is_inbound]).to eql(true)
      expect(note[:profile]).not_to eql(TEST_USER_2)
      expect(note).to have_valid_profile_link
      expect(note[:posted]).to be_valid_date_and_match_iso(note[:posted_at])
      expect(note[:description]).to be_instance_of String
      expect(note[:description]).not_to be_blank
      expect(note[:description_body]).to be_instance_of String
      expect(note[:description_body]).not_to be_blank
      expect(note[:description]).to start_with(note[:description_body])
      expect(note[:preceding_notes]).to be_instance_of Array
      expect(note[:preceding_notes].length).to eql(0)
    end

    it 'correctly parses preceding notes' do
      @fa.login_cookie = COOKIE_TEST_USER_2
      note = @fa.note(108710838)

      expect(note[:note_id]).to be_instance_of Integer
      expect(note[:note_id]).not_to be_blank
      expect(note[:subject]).to be_instance_of String
      expect(note[:subject]).not_to be_blank
      expect(note[:is_inbound]).to be_in([true, false])
      expect(note[:profile]).not_to eql(TEST_USER_2)
      expect(note).to have_valid_profile_link
      expect(note[:posted]).to be_valid_date_and_match_iso(note[:posted_at])
      expect(note[:description]).to be_instance_of String
      expect(note[:description]).not_to be_blank
      expect(note[:description_body]).to be_instance_of String
      expect(note[:description_body]).not_to be_blank
      expect(note[:description]).to start_with(note[:description_body])
      expect(note[:preceding_notes]).to be_instance_of Array
      expect(note[:preceding_notes].length).to eql(1)
      expect(note[:preceding_notes][0][:description]).to be_instance_of String
      expect(note[:preceding_notes][0][:description]).not_to be_blank
      expect(note[:preceding_notes][0]).to have_valid_profile_link
      expect(note[:preceding_notes][0][:profile]).not_to eql(TEST_USER_2)
    end

    it 'throws an error for an invalid note' do
      @fa.login_cookie = COOKIE_TEST_USER_2
      expect { @fa.note(108710839) }.to raise_error(FASystemError)
    end
  end
end
