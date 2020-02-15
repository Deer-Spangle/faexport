
require './lib/faexport'
require_relative 'check_helper'

require 'rspec'

describe 'FA comments parser' do

  before do
    config = File.exist?('settings-test.yml') ? YAML.load_file('settings-test.yml') : {}
    @app = FAExport::Application.new(config).instance_variable_get(:@instance)
    @fa = @app.instance_variable_get(:@fa)
    @fa.login_cookie = COOKIE_DEFAULT
  end

  after do
    # Do nothing
  end

  context 'on a submission' do
    it 'displays a valid list of top level comments' do
      sub_id = "16437648"
      comments = @fa.submission_comments(sub_id, false)
      expect(comments).to be_instance_of Array
      expect(comments).not_to be_empty
      comments.each do |comment|
        expect(comment[:id]).to match(/[0-9]+/)
        expect(comment).to have_valid_profile_link
        expect(comment[:avatar]).to be_valid_avatar_for_user(comment[:profile_name])
        expect(comment[:posted]).to be_valid_date_and_match_iso(comment[:posted_at])
        expect(comment[:text]).not_to be_blank
        expect(comment[:reply_to]).to be_blank
        expect(comment[:reply_level]).to be 0
      end
    end

    it 'handles empty comments section' do
      sub_id = "16437675"
      comments = @fa.submission_comments(sub_id, false)
      expect(comments).to be_instance_of Array
      expect(comments).to be_empty
    end

    it 'hides deleted comments by default' do
      submission_id = "16437663"
      comments = @fa.submission_comments(submission_id, false)
      expect(comments).to be_instance_of Array
      expect(comments.length).to be 1
      expect(comments[0][:text]).to eql("Non-deleted comment")
    end

    it 'handles comments deleted by author when specified' do
      submission_id = "16437663"
      comments = @fa.submission_comments(submission_id, true)
      expect(comments).to be_instance_of Array
      expect(comments.length).to be 2
      expect(comments[0]).to have_key(:id)
      expect(comments[0][:text]).to eql("Non-deleted comment")
      expect(comments[0][:is_deleted]).to be false
      expect(comments[1]).to have_key(:id)
      expect(comments[1][:text]).to eql("Comment hidden by its owner")
      expect(comments[1][:is_deleted]).to be true
    end

    it 'handles comments deleted by submission owner when specified' do
      submission_id = "32006442"
      comments_not_deleted = @fa.submission_comments(submission_id, false)
      expect(comments_not_deleted).to be_instance_of Array
      expect(comments_not_deleted).to be_empty
      # Ensure comments appear when viewing deleted
      comments = @fa.submission_comments(submission_id, true)
      expect(comments).to be_instance_of Array
      expect(comments.length).to be 1
      expect(comments[0]).to have_key(:id)
      expect(comments[0][:text]).to eql("Comment hidden by  the page owner")
      expect(comments[0][:is_deleted]).to be true
    end

    it 'fails when given non-existent submission' do
      expect { @fa.submission_comments("16437650", false) }.to raise_error FASystemError
    end

    it 'correctly parses replies and reply levels' do
      comments = @fa.submission_comments("32006460", false)
      # Check first comment
      expect(comments[0][:id]).not_to be_blank
      expect(comments[0][:profile_name]).to eql(TEST_USER_3)
      expect(comments[0]).to have_valid_profile_link
      expect(comments[0][:avatar]).to be_valid_avatar_for_user(comments[0][:profile_name])
      expect(comments[0][:posted]).to be_valid_date_and_match_iso(comments[0][:posted_at])
      expect(comments[0][:text]).to eql("Base comment")
      expect(comments[0][:reply_to]).to be_blank
      expect(comments[0][:reply_level]).to be 0
      # Check second comment
      expect(comments[1][:id]).not_to be_blank
      expect(comments[1][:profile_name]).to eql(TEST_USER_3)
      expect(comments[1]).to have_valid_profile_link
      expect(comments[1][:avatar]).to be_valid_avatar_for_user(comments[1][:profile_name])
      expect(comments[1][:posted]).to be_valid_date_and_match_iso(comments[1][:posted_at])
      expect(comments[1][:text]).to eql("First reply")
      expect(comments[1][:reply_to]).not_to be_blank
      expect(comments[1][:reply_to]).to eql(comments[0][:id])
      expect(comments[1][:reply_level]).to be 1
      # Check third comment
      expect(comments[2][:id]).not_to be_blank
      expect(comments[2][:profile_name]).to eql("fafeed-no-watchers")
      expect(comments[2]).to have_valid_profile_link
      expect(comments[2][:avatar]).to be_valid_avatar_for_user(comments[2][:profile_name])
      expect(comments[2][:posted]).to be_valid_date_and_match_iso(comments[2][:posted_at])
      expect(comments[2][:text]).to eql("Another reply")
      expect(comments[2][:reply_to]).not_to be_blank
      expect(comments[2][:reply_to]).to eql(comments[1][:id])
      expect(comments[2][:reply_level]).to be 2
    end

    it 'handles replies to deleted comments' do
      comments = @fa.submission_comments("32052941", true)
      expect(comments).to be_instance_of Array
      expect(comments.length).to be 2
      # Check hidden comment
      expect(comments[1][:id]).not_to be_blank
      expect(comments[0][:text]).to start_with("Comment hidden by")
      expect(comments[0][:reply_to]).to eql("")
      expect(comments[0][:reply_level]).to be 0
      expect(comments[0][:is_deleted]).to be true
      # Check reply comment
      expect(comments[1][:id]).not_to be_blank
      expect(comments[1][:text]).not_to start_with("Comment hidden by")
      expect(comments[1]).to have_key(:profile_name)
      expect(comments[1][:reply_level]).to be 1
      expect(comments[1][:reply_to]).not_to be_blank
      expect(comments[1][:is_deleted]).to be false
    end

    it 'handles replies to hidden deleted comments' do
      comments = @fa.submission_comments("32052941", false)
      expect(comments).to be_instance_of Array
      expect(comments.length).to be 1
      # Reply comment should be only comment
      expect(comments[0][:id]).not_to be_blank
      expect(comments[0][:text]).not_to start_with("Comment hidden by")
      expect(comments[0]).to have_key(:profile_name)
      expect(comments[0][:reply_level]).to be 1
      expect(comments[0][:reply_to]).not_to be_blank
    end

    it 'handles 2 replies to the same comment' do
      comments = @fa.submission_comments("32057670", false)
      expect(comments).to be_instance_of Array
      expect(comments.length).to be 3
      # Base comment
      expect(comments[0][:id]).not_to be_blank
      expect(comments[0][:text]).to eql("Base level comment")
      expect(comments[0][:reply_level]).to be 0
      expect(comments[0][:reply_to]).to eql("")
      # First reply
      expect(comments[1][:id]).not_to be_blank
      expect(comments[1][:text]).to eql("First reply comment")
      expect(comments[1][:reply_level]).to be 1
      expect(comments[1][:reply_to]).to eql(comments[0][:id])
      # Second reply
      expect(comments[2][:id]).not_to be_blank
      expect(comments[2][:text]).to eql("Second reply comment")
      expect(comments[2][:reply_level]).to be 1
      expect(comments[2][:reply_to]).to eql(comments[0][:id])
    end

    it 'handles deleted replies to deleted comments' do
      comments = @fa.submission_comments("32057697", true)
      expect(comments).to be_instance_of Array
      expect(comments.length).to be 2
      # Check hidden comment
      expect(comments[0][:id]).not_to be_blank
      expect(comments[0][:text]).to start_with("Comment hidden by")
      expect(comments[0][:reply_level]).to be 0
      expect(comments[0][:reply_to]).to eql("")
      expect(comments[0][:is_deleted]).to be true
      # Check reply comment
      expect(comments[0][:id]).not_to be_blank
      expect(comments[1][:text]).to start_with("Comment hidden by")
      expect(comments[1][:reply_level]).to be 1
      expect(comments[1][:reply_to]).to eql(comments[0][:id])
      expect(comments[0][:is_deleted]).to be true
    end

    it 'handles comments to max depth' do
      comments = @fa.submission_comments("32057717", false)
      expect(comments).to be_instance_of Array
      expect(comments.length).to be 22
      last_comment_id = ""
      level = 0
      comments.each do |comment|
        expect(comment[:id]).to match(/[0-9]+/)
        expect(comment).to have_valid_profile_link
        expect(comment[:avatar]).to be_valid_avatar_for_user(comment[:profile_name])
        expect(comment[:posted]).to be_valid_date_and_match_iso(comment[:posted_at])
        expect(comment[:text]).not_to be_blank
        expect(comment[:reply_to]).to eql(last_comment_id)
        expect(comment[:reply_level]).to be level

        if level <= 19
          last_comment_id = comment[:id]
          level += 1
        end
      end
    end

    it 'handles edited comments' do
      comments = @fa.submission_comments("32057705", false)
      expect(comments).to be_instance_of Array
      expect(comments.length).to be 2
      # Check edited comment
      expect(comments[0][:id]).to match(/[0-9]+/)
      expect(comments[0]).to have_valid_profile_link
      expect(comments[0][:avatar]).to be_valid_avatar_for_user(comments[0][:profile_name])
      expect(comments[0][:posted]).to be_valid_date_and_match_iso(comments[0][:posted_at])
      expect(comments[0][:text]).not_to be_blank
      expect(comments[0][:reply_to]).to be_blank
      expect(comments[0][:reply_level]).to be 0
      # Check non-edited comment
      expect(comments[1][:id]).to match(/[0-9]+/)
      expect(comments[1]).to have_valid_profile_link
      expect(comments[1][:avatar]).to be_valid_avatar_for_user(comments[1][:profile_name])
      expect(comments[1][:posted]).to be_valid_date_and_match_iso(comments[1][:posted_at])
      expect(comments[1][:text]).not_to be_blank
      expect(comments[1][:reply_to]).to be_blank
      expect(comments[1][:reply_level]).to be 0
    end

    it 'handles reply chain, followed by reply to base comment' do
      comments = @fa.submission_comments("32058026", false)
      expect(comments).to be_instance_of Array
      expect(comments.length).to be 4
      # Check base comment
      expect(comments[0][:id]).to match(/[0-9]+/)
      expect(comments[0][:text]).to eql("Base comment")
      expect(comments[0][:reply_to]).to eql("")
      expect(comments[0][:reply_level]).to be 0
      # Check first reply
      expect(comments[1][:id]).to match(/[0-9]+/)
      expect(comments[1][:text]).to eql("First reply")
      expect(comments[1][:reply_to]).to eql(comments[0][:id])
      expect(comments[1][:reply_level]).to be 1
      # Check deep reply
      expect(comments[2][:id]).to match(/[0-9]+/)
      expect(comments[2][:text]).to eql("Deep reply")
      expect(comments[2][:reply_to]).to eql(comments[1][:id])
      expect(comments[2][:reply_level]).to be 2
      # Check second reply
      expect(comments[3][:id]).to match(/[0-9]+/)
      expect(comments[3][:text]).to eql("Second base reply")
      expect(comments[3][:reply_to]).to eql(comments[0][:id])
      expect(comments[3][:reply_level]).to be 1
    end
  end

  context 'on a journal' do
    it 'displays a valid list of top level comments' do
      journal_id = "6704315"
      comments = @fa.journal_comments(journal_id, false)
      expect(comments).to be_instance_of Array
      expect(comments).not_to be_empty
      comments.each do |comment|
        expect(comment[:id]).to match(/[0-9]+/)
        expect(comment).to have_valid_profile_link
        expect(comment[:avatar]).to be_valid_avatar_for_user(comment[:profile_name])
        expect(comment[:posted]).to be_valid_date_and_match_iso(comment[:posted_at])
        expect(comment[:text]).not_to be_blank
        expect(comment[:reply_to]).to be_blank
        expect(comment[:reply_level]).to be 0
      end
    end

    it 'handles empty comments section' do
      journal_id = "6704317"
      comments = @fa.journal_comments(journal_id, false)
      expect(comments).to be_instance_of Array
      expect(comments).to be_empty
    end

    it 'hides deleted comments by default' do
      journal_id = "6704520"
      comments = @fa.journal_comments(journal_id, false)
      expect(comments).to be_instance_of Array
      expect(comments.length).to be 1
      expect(comments[0][:text]).to eql("Non-deleted comment")
    end

    it 'handles comments deleted by author when specified' do
      journal_id = "6704520"
      comments = @fa.journal_comments(journal_id, true)
      expect(comments).to be_instance_of Array
      expect(comments.length).to be 2
      expect(comments[0]).to have_key(:id)
      expect(comments[0][:text]).to eql("Non-deleted comment")
      expect(comments[0][:is_deleted]).to be false
      expect(comments[1]).to have_key(:id)
      expect(comments[1][:text]).to eql("Comment hidden by its owner")
      expect(comments[1][:is_deleted]).to be true
    end

    it 'handles comments deleted by journal owner when specified' do
      journal_id = "9185920"
      comments_not_deleted = @fa.journal_comments(journal_id, false)
      expect(comments_not_deleted).to be_instance_of Array
      expect(comments_not_deleted).to be_empty
      # Ensure comments appear when viewing deleted
      comments = @fa.journal_comments(journal_id, true)
      expect(comments).to be_instance_of Array
      expect(comments.length).to be 1
      expect(comments[0]).to have_key(:id)
      expect(comments[0][:text]).to eql("Comment hidden by  the page owner")
      expect(comments[0][:is_deleted]).to be true
    end

    it 'fails when given non-existent journal' do
      expect { @fa.journal_comments("6894929", false) }.to raise_error(FASystemError)
    end

    it 'correctly parses replies and reply levels' do
      comments = @fa.journal_comments("6894788", false)
      # Check first comment
      expect(comments[0][:id]).not_to be_blank
      expect(comments[0][:profile_name]).to eql(TEST_USER_3)
      expect(comments[0]).to have_valid_profile_link
      expect(comments[0][:avatar]).to be_valid_avatar_for_user(comments[0][:profile_name])
      expect(comments[0][:posted]).to be_valid_date_and_match_iso(comments[0][:posted_at])
      expect(comments[0][:text]).to eql("Base journal comment")
      expect(comments[0][:reply_to]).to be_blank
      expect(comments[0][:reply_level]).to be 0
      # Check second comments
      expect(comments[1][:id]).not_to be_blank
      expect(comments[1][:profile_name]).to eql(TEST_USER_3)
      expect(comments[1]).to have_valid_profile_link
      expect(comments[1][:avatar]).to be_valid_avatar_for_user(comments[1][:profile_name])
      expect(comments[1][:posted]).to be_valid_date_and_match_iso(comments[1][:posted_at])
      expect(comments[1][:text]).to eql("Reply to journal comment")
      expect(comments[1][:reply_to]).not_to be_blank
      expect(comments[1][:reply_to]).to eql(comments[0][:id])
      expect(comments[1][:reply_level]).to be 1
      # Check third comments
      expect(comments[2][:id]).not_to be_blank
      expect(comments[2][:profile_name]).to eql("fafeed-no-watchers")
      expect(comments[2]).to have_valid_profile_link
      expect(comments[2][:avatar]).to be_valid_avatar_for_user(comments[2][:profile_name])
      expect(comments[2][:posted]).to be_valid_date_and_match_iso(comments[2][:posted_at])
      expect(comments[2][:text]).to eql("Another reply on this journal")
      expect(comments[2][:reply_to]).not_to be_blank
      expect(comments[2][:reply_to]).to eql(comments[1][:id])
      expect(comments[2][:reply_level]).to be 2
    end

    it 'handles replies to deleted comments' do
      comments = @fa.journal_comments("9187935", true)
      expect(comments).to be_instance_of Array
      expect(comments.length).to be 2
      # Check hidden comment
      expect(comments[0][:id]).not_to be_blank
      expect(comments[0][:text]).to start_with("Comment hidden by")
      expect(comments[0][:reply_to]).to eql("")
      expect(comments[0][:reply_level]).to be 0
      expect(comments[0][:is_deleted]).to be true
      # Check reply comment
      expect(comments[1][:id]).not_to be_blank
      expect(comments[1][:text]).not_to start_with("Comment hidden by")
      expect(comments[1]).to have_key(:profile_name)
      expect(comments[1][:reply_level]).to be 1
      expect(comments[1][:reply_to]).to eql(comments[0][:id])
      expect(comments[1][:is_deleted]).to be false
    end

    it 'handles replies to hidden deleted comments' do
      comments = @fa.journal_comments("9187935", false)
      expect(comments).to be_instance_of Array
      expect(comments.length).to be 1
      # Reply comment should be only comment
      expect(comments[0][:id]).not_to be_blank
      expect(comments[0][:text]).not_to start_with("Comment hidden by")
      expect(comments[0]).to have_key(:profile_name)
      expect(comments[0][:reply_level]).to be 1
      expect(comments[0][:reply_to]).not_to be_blank
    end

    it 'handles 2 replies to the same comment' do
      comments = @fa.journal_comments("9187933", false)
      expect(comments).to be_instance_of Array
      expect(comments.length).to be 3
      # Base comment
      expect(comments[0][:id]).not_to be_blank
      expect(comments[0][:text]).to eql("Base comment")
      expect(comments[0][:reply_level]).to be 0
      expect(comments[0][:reply_to]).to eql("")
      # First reply
      expect(comments[1][:id]).not_to be_blank
      expect(comments[1][:text]).to eql("First reply")
      expect(comments[1][:reply_level]).to be 1
      expect(comments[1][:reply_to]).to eql(comments[0][:id])
      # Second reply
      expect(comments[2][:id]).not_to be_blank
      expect(comments[2][:text]).to eql("Second reply")
      expect(comments[2][:reply_level]).to be 1
      expect(comments[2][:reply_to]).to eql(comments[0][:id])
    end

    it 'handles deleted replies to deleted comments' do
      comments = @fa.journal_comments("9187934", true)
      expect(comments).to be_instance_of Array
      expect(comments.length).to be 2
      # Check hidden comment
      expect(comments[0]).to have_key(:id)
      expect(comments[0][:text]).to start_with("Comment hidden by")
      expect(comments[0][:reply_level]).to be 0
      expect(comments[0][:reply_to]).to eql("")
      expect(comments[0][:is_deleted]).to be true
      # Check reply comment
      expect(comments[1]).to have_key(:id)
      expect(comments[1][:text]).to start_with("Comment hidden by")
      expect(comments[1][:reply_level]).to be 1
      expect(comments[1][:reply_to]).to eql(comments[0][:id])
      expect(comments[1][:is_deleted]).to be true
    end

    it 'handles comments to max depth' do
      comments = @fa.submission_comments("32057717", false)
      expect(comments).to be_instance_of Array
      expect(comments.length).to be 22
      last_comment_id = ""
      level = 0
      comments.each do |comment|
        expect(comment[:id]).to match(/[0-9]+/)
        expect(comment).to have_valid_profile_link
        expect(comment[:avatar]).to be_valid_avatar_for_user(comment[:profile_name])
        expect(comment[:posted]).to be_valid_date_and_match_iso(comment[:posted_at])
        expect(comment[:text]).not_to be_blank
        expect(comment[:reply_to]).to eql(last_comment_id)
        expect(comment[:reply_level]).to be level

        if level <= 19
          last_comment_id = comment[:id]
          level += 1
        end
      end
    end

    it 'handles edited comments' do
      comments = @fa.journal_comments("9187948", false)
      expect(comments).to be_instance_of Array
      expect(comments.length).to be 2
      # Check edited comment
      expect(comments[0][:id]).to match(/[0-9]+/)
      expect(comments[0]).to have_valid_profile_link
      expect(comments[0][:avatar]).to be_valid_avatar_for_user(comments[0][:profile_name])
      expect(comments[0][:posted]).to be_valid_date_and_match_iso(comments[0][:posted_at])
      expect(comments[0][:text]).not_to be_blank
      expect(comments[0][:reply_to]).to be_blank
      expect(comments[0][:reply_level]).to be 0
      # Check non-edited comment
      expect(comments[1][:id]).to match(/[0-9]+/)
      expect(comments[1]).to have_valid_profile_link
      expect(comments[1][:avatar]).to be_valid_avatar_for_user(comments[1][:profile_name])
      expect(comments[1][:posted]).to be_valid_date_and_match_iso(comments[1][:posted_at])
      expect(comments[1][:text]).not_to be_blank
      expect(comments[1][:reply_to]).to be_blank
      expect(comments[1][:reply_level]).to be 0
    end

    it 'handles reply chain, followed by reply to base comment' do
      comments = @fa.journal_comments("9187949", false)
      expect(comments).to be_instance_of Array
      expect(comments.length).to be 4
      # Check base comment
      expect(comments[0][:id]).to match(/[0-9]+/)
      expect(comments[0][:text]).to eql("Base comment")
      expect(comments[0][:reply_to]).to eql("")
      expect(comments[0][:reply_level]).to be 0
      # Check first reply
      expect(comments[1][:id]).to match(/[0-9]+/)
      expect(comments[1][:text]).to eql("First reply")
      expect(comments[1][:reply_to]).to eql(comments[0][:id])
      expect(comments[1][:reply_level]).to be 1
      # Check deep reply
      expect(comments[2][:id]).to match(/[0-9]+/)
      expect(comments[2][:text]).to eql("Deep reply")
      expect(comments[2][:reply_to]).to eql(comments[1][:id])
      expect(comments[2][:reply_level]).to be 2
      # Check second reply
      expect(comments[3][:id]).to match(/[0-9]+/)
      expect(comments[3][:text]).to eql("Second base reply")
      expect(comments[3][:reply_to]).to eql(comments[0][:id])
      expect(comments[3][:reply_level]).to be 1
    end
  end

end
