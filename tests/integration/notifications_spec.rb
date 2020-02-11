
require './lib/faexport'
require_relative 'check_helper'

require 'rspec'

describe 'FA notifications parser' do
  COOKIE_DEFAULT = ENV['test_cookie']

  before do
    config = File.exist?('settings-test.yml') ? YAML.load_file('settings-test.yml') : {}
    @app = FAExport::Application.new(config).instance_variable_get(:@instance)
    @fa = @app.instance_variable_get(:@fa)
    @fa.login_cookie = COOKIE_DEFAULT
  end

  after do
    # Do nothing
end

  it 'will correctly parse current user' do
    @fa.login_cookie = COOKIE_TEST_USER_2
    notifications = @fa.notifications(false)
    expect(notifications[:current_user][:name]).to eql(TEST_USER_2)
    expect(notifications[:current_user]).to have_valid_profile_link
  end

  it 'should not return anything unless login cookie is given' do
    @fa.login_cookie = nil
    expect { @fa.notifications(false) }.to raise_error(FALoginError)
  end

  it 'should display non-zero notification totals' do
    @fa.login_cookie = COOKIE_TEST_USER_2
    notifications = @fa.notifications(false)
    expect(notifications).to have_key(:notification_counts)
    counts = notifications[:notification_counts]
    expect(counts).to have_key(:submissions)
    expect(counts).to have_key(:comments)
    expect(counts).to have_key(:journals)
    expect(counts).to have_key(:favorites)
    expect(counts).to have_key(:watchers)
    expect(counts).to have_key(:notes)
    expect(counts).to have_key(:trouble_tickets)

    expect(counts[:submissions]).to be >= 0
    expect(counts[:comments]).to be > 0
    expect(counts[:journals]).to be >= 0
    expect(counts[:favorites]).to be > 0
    expect(counts[:watchers]).to be > 0
    expect(counts[:notes]).to be > 0
    expect(counts[:trouble_tickets]).to be >= 0
  end

  it 'should contain all 6 types of notifications' do
    @fa.login_cookie = COOKIE_TEST_USER_2
    notifications = @fa.notifications(false)
    expect(notifications).to have_key(:new_watches)
    expect(notifications).to have_key(:new_submission_comments)
    expect(notifications).to have_key(:new_journal_comments)
    expect(notifications).to have_key(:new_shouts)
    expect(notifications).to have_key(:new_favorites)
    expect(notifications).to have_key(:new_journals)
  end

  context 'watcher notifications' do
    it 'should handle zero new watchers' do
      @fa.login_cookie = COOKIE_TEST_USER_3
      watchers = @fa.notifications(false)[:new_watches]
      expect(watchers).to be_instance_of Array
      expect(watchers).to be_empty
    end

    it 'returns a list of new watcher notifications' do
      @fa.login_cookie = COOKIE_TEST_USER_2
      watchers = @fa.notifications(false)[:new_watches]
      expect(watchers).to be_instance_of Array
      expect(watchers).not_to be_empty
      watchers.each do |watcher|
        expect(watcher[:watch_id]).to match(/[0-9]+/)
        expect(watcher).to have_valid_profile_link
        expect(watcher[:avatar]).to be_valid_avatar_for_user(watcher[:profile_name])
        expect(watcher[:posted]).to be_valid_date_and_match_iso(watcher[:posted_at])
      end
    end

    it 'should hide deleted watcher notifications by default' do
      @fa.login_cookie = COOKIE_TEST_USER_2
      watchers = @fa.notifications(false)[:new_watches]
      expect(watchers).to be_instance_of Array
      expect(watchers).not_to be_empty
      expect(watchers.length).to be 1
    end

    it 'should display deleted watcher notifications when specified and hide otherwise' do
      skip "Skipped: Looks like deleted watcher notifications don't display anymore"
      @fa.login_cookie = COOKIE_TEST_USER_2
      watchers = @fa.notifications(false)[:new_watches]
      expect(watchers).to be_instance_of Array
      expect(watchers).not_to be_empty

      watchers_deleted = @fa.notifications(true)[:new_watches]
      expect(watchers_deleted).to be_instance_of Array
      expect(watchers_deleted).not_to be_empty

      expect(watchers_deleted.length).to be > watchers.length

      deleted_watch = watchers_deleted[-1]
      expect(deleted_watch[:watch_id]).to eql("")
      expect(deleted_watch[:name]).to eql("Removed by the user")
      expect(deleted_watch[:profile]).to eql("")
      expect(deleted_watch[:profile_name]).to eql("")
      expect(deleted_watch[:avatar]).to eql("I forgot the link.")
      expect(deleted_watch[:posted]).to eql("")
      expect(deleted_watch[:posted_at]).to eql("")
    end
  end

  context 'submission comment notifications' do
    it 'should handle zero submission comment notifications' do
      @fa.login_cookie = COOKIE_TEST_USER_NO_NOTIFICATIONS
      notifications = @fa.notifications(false)[:new_submission_comments]
      expect(notifications).to be_instance_of Array
      expect(notifications).to be_empty
    end

    it 'returns a list of new submission comment notifications' do
      @fa.login_cookie = COOKIE_TEST_USER_2
      notifications = @fa.notifications(false)[:new_submission_comments]
      expect(notifications).to be_instance_of Array
      expect(notifications).not_to be_empty
      notifications.each do |comment_notification|
        expect(comment_notification[:comment_id]).to match(/[0-9]+/)
        expect(comment_notification).to have_valid_profile_link
        expect(comment_notification[:is_reply]).to be_in([true, false])
        expect(comment_notification[:your_submission]).to be_in([true, false])
        expect(comment_notification[:their_submission]).to be_in([true, false])
        # Can't be both yours and theirs
        expect(comment_notification[:your_submission] && comment_notification[:their_submission]).to be false
        expect(comment_notification[:submission_id]).to match(/[0-9]+/)
        expect(comment_notification[:title]).not_to be_blank
        expect(comment_notification[:posted]).to be_valid_date_and_match_iso(comment_notification[:posted_at])
      end
    end

    it 'correctly parses base level comments to your submissions' do
      @fa.login_cookie = COOKIE_TEST_USER_2
      notifications = @fa.notifications(false)[:new_submission_comments]
      expect(notifications).to be_instance_of Array
      expect(notifications).not_to be_empty

      found_comment = false

      notifications.each do |comment_notification|
        if !comment_notification[:is_reply] &&
            comment_notification[:your_submission] &&
            !comment_notification[:their_submission]
          found_comment = true
        end
      end

      expect(found_comment).to be true
    end

    it 'correctly parses replies to your comments on your submissions' do
      @fa.login_cookie = COOKIE_TEST_USER_2
      notifications = @fa.notifications(false)[:new_submission_comments]
      expect(notifications).to be_instance_of Array
      expect(notifications).not_to be_empty

      found_comment = false

      notifications.each do |comment_notification|
        if comment_notification[:is_reply] &&
            comment_notification[:your_submission] &&
            !comment_notification[:their_submission]
          found_comment = true
        end
      end

      expect(found_comment).to be true
    end

    it 'correctly parses replies to your comments on their submissions' do
      @fa.login_cookie = COOKIE_TEST_USER_2
      notifications = @fa.notifications(false)[:new_submission_comments]
      expect(notifications).to be_instance_of Array
      expect(notifications).not_to be_empty

      found_comment = false

      notifications.each do |comment_notification|
        if comment_notification[:is_reply] &&
            !comment_notification[:your_submission] &&
            comment_notification[:their_submission]
          found_comment = true
        end
      end

      expect(found_comment).to be true
    end

    it 'correctly parses replies to your comments on someone else\'s submissions' do
      @fa.login_cookie = COOKIE_TEST_USER_2
      notifications = @fa.notifications(false)[:new_submission_comments]
      expect(notifications).to be_instance_of Array
      expect(notifications).not_to be_empty

      found_comment = false

      notifications.each do |comment_notification|
        if comment_notification[:is_reply] &&
            !comment_notification[:your_submission] &&
            !comment_notification[:their_submission]
          found_comment = true
        end
      end

      expect(found_comment).to be true
    end

    it 'displays deleted submission comment notifications when specified and hide otherwise' do
      @fa.login_cookie = COOKIE_TEST_USER_2
      notifications = @fa.notifications(false)[:new_submission_comments]
      expect(notifications).to be_instance_of Array
      expect(notifications).not_to be_empty

      notifications_include = @fa.notifications(true)[:new_submission_comments]
      expect(notifications_include).to be_instance_of Array
      expect(notifications_include).not_to be_empty

      expect(notifications_include.length).to be > notifications.length

      deleted = notifications_include - notifications

      deleted.each do |deleted_comment|
        expect(deleted_comment[:comment_id]).to eql("")
        expect(deleted_comment[:name]).to eql("Comment or the submission it was left on has been deleted")
        expect(deleted_comment[:profile]).to eql("")
        expect(deleted_comment[:profile_name]).to eql("")
        expect(deleted_comment[:is_reply]).to be false
        expect(deleted_comment[:your_submission]).to be false
        expect(deleted_comment[:their_submission]).to be false
        expect(deleted_comment[:submission_id]).to eql("")
        expect(deleted_comment[:title]).to eql("Comment or the submission it was left on has been deleted")
        expect(deleted_comment[:posted]).to eql("")
        expect(deleted_comment[:posted_at]).to eql("")
      end
    end
  end

  context 'journal comment notifications' do
    it 'should handle zero journal comment notifications' do
      @fa.login_cookie = COOKIE_TEST_USER_NO_NOTIFICATIONS
      notifications = @fa.notifications(false)[:new_journal_comments]
      expect(notifications).to be_instance_of Array
      expect(notifications).to be_empty
    end

    it 'returns a list of new journal comment notifications' do
      @fa.login_cookie = COOKIE_TEST_USER_2
      notifications = @fa.notifications(false)[:new_journal_comments]
      expect(notifications).to be_instance_of Array
      expect(notifications).not_to be_empty
      notifications.each do |comment_notification|
        expect(comment_notification[:comment_id]).to match(/[0-9]+/)
        expect(comment_notification).to have_valid_profile_link
        expect(comment_notification[:is_reply]).to be_in([true, false])
        expect(comment_notification[:your_journal]).to be_in([true, false])
        expect(comment_notification[:their_journal]).to be_in([true, false])
        expect(comment_notification[:your_journal] && comment_notification[:their_journal]).to be false
        expect(comment_notification[:journal_id]).to match(/[0-9]+/)
        expect(comment_notification[:title]).not_to be_blank
        expect(comment_notification[:posted]).to be_valid_date_and_match_iso(comment_notification[:posted_at])
      end
    end

    it 'correctly parses base level comments to your journals' do
      @fa.login_cookie = COOKIE_TEST_USER_2
      notifications = @fa.notifications(false)[:new_journal_comments]
      expect(notifications).to be_instance_of Array
      expect(notifications).not_to be_empty

      found_comment = false

      notifications.each do |comment_notification|
        if !comment_notification[:is_reply] &&
            comment_notification[:your_journal] &&
            !comment_notification[:their_journal]
          found_comment = true
        end
      end

      expect(found_comment).to be true
    end

    it 'correctly parses replies to your comments on your journals' do
      @fa.login_cookie = COOKIE_TEST_USER_2
      notifications = @fa.notifications(false)[:new_journal_comments]
      expect(notifications).to be_instance_of Array
      expect(notifications).not_to be_empty

      found_comment = false

      notifications.each do |comment_notification|
        if comment_notification[:is_reply] &&
            comment_notification[:your_journal] &&
            !comment_notification[:their_journal]
          found_comment = true
        end
      end

      expect(found_comment).to be true
    end

    it 'correctly parses replies to your comments on their journals' do
      @fa.login_cookie = COOKIE_TEST_USER_2
      notifications = @fa.notifications(false)[:new_journal_comments]
      expect(notifications).to be_instance_of Array
      expect(notifications).not_to be_empty

      found_comment = false

      notifications.each do |comment_notification|
        if comment_notification[:is_reply] &&
            !comment_notification[:your_journal] &&
            comment_notification[:their_journal]
          found_comment = true
        end
      end

      expect(found_comment).to be true
    end

    it 'correctly parses replies to your comments on someone else\'s journals' do
      @fa.login_cookie = COOKIE_TEST_USER_2
      notifications = @fa.notifications(false)[:new_journal_comments]
      expect(notifications).to be_instance_of Array
      expect(notifications).not_to be_empty

      found_comment = false

      notifications.each do |comment_notification|
        if comment_notification[:is_reply] &&
            !comment_notification[:your_journal] &&
            !comment_notification[:their_journal]
          found_comment = true
        end
      end

      expect(found_comment).to be true
    end

    it 'displays deleted journal comment notifications when specified and hide otherwise' do
      @fa.login_cookie = COOKIE_TEST_USER_2
      notifications = @fa.notifications(false)[:new_journal_comments]
      expect(notifications).to be_instance_of Array
      expect(notifications).not_to be_empty

      notifications_include = @fa.notifications(true)[:new_journal_comments]
      expect(notifications_include).to be_instance_of Array
      expect(notifications_include).not_to be_empty

      expect(notifications_include.length).to be > notifications.length

      deleted = notifications_include - notifications

      deleted.each do |deleted_comment|
        expect(deleted_comment[:comment_id]).to eql("")
        expect(deleted_comment[:name]).to eql("Comment or the journal it was left on has been deleted")
        expect(deleted_comment[:profile]).to eql("")
        expect(deleted_comment[:profile_name]).to eql("")
        expect(deleted_comment[:is_reply]).to be false
        expect(deleted_comment[:your_journal]).to be false
        expect(deleted_comment[:their_journal]).to be false
        expect(deleted_comment[:journal_id]).to eql("")
        expect(deleted_comment[:title]).to eql("Comment or the journal it was left on has been deleted")
        expect(deleted_comment[:posted]).to eql("")
        expect(deleted_comment[:posted_at]).to eql("")
      end
    end
  end

  context 'shout notifications' do
    it 'should handle zero shout notifications' do
      @fa.login_cookie = COOKIE_TEST_USER_NO_NOTIFICATIONS
      notifications = @fa.notifications(false)[:new_shouts]
      expect(notifications).to be_instance_of Array
      expect(notifications).to be_empty
    end

    it 'returns a list of new shout notifications' do
      @fa.login_cookie = COOKIE_TEST_USER_2
      notifications = @fa.notifications(false)[:new_shouts]
      expect(notifications).to be_instance_of Array
      expect(notifications).not_to be_empty

      notifications.each do |new_shout|
        expect(new_shout[:shout_id]).to match(/[0-9]+/)
        expect(new_shout).to have_valid_profile_link
        expect(new_shout[:posted]).to be_valid_date_and_match_iso(new_shout[:posted_at])
      end
    end

    it 'displays deleted shout notifications when specified and hides otherwise' do
      @fa.login_cookie = COOKIE_TEST_USER_2
      notifications = @fa.notifications(false)[:new_shouts]
      expect(notifications).to be_instance_of Array
      expect(notifications).not_to be_empty

      notifications_include = @fa.notifications(true)[:new_shouts]
      expect(notifications_include).to be_instance_of Array
      expect(notifications_include).not_to be_empty

      expect(notifications_include.length).to be > notifications.length

      deleted = notifications_include - notifications

      deleted.each do |deleted_shout|
        expect(deleted_shout[:shout_id]).to eql("")
        expect(deleted_shout[:name]).to eql("Shout has been removed from your page")
        expect(deleted_shout[:profile]).to eql("")
        expect(deleted_shout[:profile_name]).to eql("")
        expect(deleted_shout[:posted]).to eql("")
        expect(deleted_shout[:posted_at]).to eql("")
      end
    end
  end

  context 'favourite notifications' do
    it 'should handle zero favourite notifications' do
      @fa.login_cookie = COOKIE_TEST_USER_NO_NOTIFICATIONS
      notifications = @fa.notifications(false)[:new_favorites]
      expect(notifications).to be_instance_of Array
      expect(notifications).to be_empty
    end

    it 'returns a list of new favourite notifications' do
      @fa.login_cookie = COOKIE_TEST_USER_2
      notifications = @fa.notifications(false)[:new_favorites]
      expect(notifications).to be_instance_of Array
      expect(notifications).not_to be_empty

      notifications.each do |new_fav|
        expect(new_fav[:favorite_notification_id]).to match(/[0-9]+/)
        expect(new_fav).to have_valid_profile_link
        expect(new_fav[:submission_id]).to match(/[0-9]+/)
        expect(new_fav[:submission_name]).not_to be_blank
        expect(new_fav[:posted]).to be_valid_date_and_match_iso(new_fav[:posted_at])
      end
    end

    it 'displays deleted favourite notifications when specified and hides otherwise' do
      skip "Skipped: Looks like deleted favourite notifications don't display anymore"
      @fa.login_cookie = COOKIE_TEST_USER_2
      notifications = @fa.notifications(false)[:new_favorites]
      expect(notifications).to be_instance_of Array
      expect(notifications).not_to be_empty

      notifications_include = @fa.notifications(true)[:new_favorites]
      expect(notifications_include).to be_instance_of Array
      expect(notifications_include).not_to be_empty

      expect(notifications_include.length).to be > notifications.length

      deleted = notifications_include - notifications

      deleted.each do |deleted_fav|
        expect(deleted_fav[:favorite_notification_id]).to eql("")
        expect(deleted_fav[:name]).to eql("The favorite this notification was for has since been removed by the user")
        expect(deleted_fav[:profile]).to eql("")
        expect(deleted_fav[:profile_name]).to eql("")
        expect(deleted_fav[:submission_id]).to eql("")
        expect(deleted_fav[:submission_name]).to eql("The favorite this notification was for has since been removed by the user")
        expect(deleted_fav[:posted]).to eql("")
        expect(deleted_fav[:posted_at]).to eql("")
      end
    end
  end

  context 'journal notifications' do
    it 'should handle zero new journals' do
      @fa.login_cookie = COOKIE_TEST_USER_NO_NOTIFICATIONS
      notifications = @fa.notifications(false)[:new_journals]
      expect(notifications).to be_instance_of Array
      expect(notifications).to be_empty
    end

    it 'returns a list of new journal notifications' do
      @fa.login_cookie = COOKIE_TEST_USER_3
      notifications = @fa.notifications(false)[:new_journals]
      expect(notifications).to be_instance_of Array
      expect(notifications).not_to be_empty

      notifications.each do |new_journal|
        expect(new_journal[:journal_id]).to match(/[0-9]+/)
        expect(new_journal[:title]).not_to be_blank
        expect(new_journal).to have_valid_profile_link
        expect(new_journal[:posted]).to be_valid_date_and_match_iso(new_journal[:posted_at])
      end
    end
  end
end
