
require './lib/faexport'
require_relative 'check_helper'

require 'rspec'

describe 'FA journal post parser' do

  before do
    config = File.exist?('settings-test.yml') ? YAML.load_file('settings-test.yml') : {}
    @app = FAExport::Application.new(config).instance_variable_get(:@instance)
    @fa = @app.instance_variable_get(:@fa)
    @fa.login_cookie = COOKIE_DEFAULT
  end

  after do
    # Do nothing
  end

  it 'displays basic data correctly' do
    journal_id = "6894930"
    journal = @fa.journal(journal_id)
    expect(journal[:title]).to eql("From Curl")
    expect(journal[:description]).to start_with("<div class=\"journal-body\">")
    expect(journal[:description]).to include("Curl Test")
    expect(journal[:description]).to end_with("</div>")
    expect(journal[:journal_header]).to be_nil
    expect(journal[:journal_body]).to eql("Curl Test")
    expect(journal[:journal_footer]).to be_nil
    expect(journal).to have_valid_profile_link
    expect(journal[:avatar]).to be_valid_avatar_for_user(journal[:profile_name])
    expect(journal[:link]).to match(/https:\/\/www.furaffinity.net\/journal\/#{journal_id}\/?/)
    expect(journal[:posted]).to be_valid_date_and_match_iso(journal[:posted_at])
  end

  it 'fails when given non-existent journal' do
    expect { @fa.journal("6894929") }.to raise_error(FASystemError)
  end

  it 'parses journal header, body and footer' do
    journal_id = "9185920"
    journal = @fa.journal(journal_id)
    expect(journal[:title]).to eql("Test journal")
    expect(journal[:description]).to start_with("<div class=\"journal-header\">")
    expect(journal[:description]).to include("Example test header")
    expect(journal[:description]).to include("<div class=\"journal-body\">")
    expect(journal[:description]).to include("This is an example test journal, with header and footer")
    expect(journal[:description]).to include("<div class=\"journal-footer\">")
    expect(journal[:description]).to include("Example test footer")
    expect(journal[:description]).to end_with("</div>")
    expect(journal[:journal_header]).to eql("Example test header")
    expect(journal[:journal_body]).to eql("This is an example test journal, with header and footer")
    expect(journal[:journal_footer]).to eql("Example test footer")
    expect(journal).to have_valid_profile_link
    expect(journal[:avatar]).to be_valid_avatar_for_user(journal[:profile_name])
    expect(journal[:link]).to match(/https:\/\/www.furaffinity.net\/journal\/#{journal_id}\/?/)
    expect(journal[:posted]).to be_valid_date_and_match_iso(journal[:posted_at])
  end

  it 'handles non existent journal header' do
    journal_id = "9185944"
    journal = @fa.journal(journal_id)
    expect(journal[:title]).to eql("Testing journals")
    expect(journal[:description]).to start_with("<div class=\"journal-body\">")
    expect(journal[:description]).to include("Another test of journals, this one is for footer only")
    expect(journal[:description]).to include("<div class=\"journal-footer\">")
    expect(journal[:description]).to include("Footer, no header though")
    expect(journal[:description]).to end_with("</div>")
    expect(journal[:journal_header]).to be_nil
    expect(journal[:journal_body]).to eql("Another test of journals, this one is for footer only")
    expect(journal[:journal_footer]).to eql("Footer, no header though")
    expect(journal).to have_valid_profile_link
    expect(journal[:avatar]).to be_valid_avatar_for_user(journal[:profile_name])
    expect(journal[:link]).to match(/https:\/\/www.furaffinity.net\/journal\/#{journal_id}\/?/)
    expect(journal[:posted]).to be_valid_date_and_match_iso(journal[:posted_at])
  end
end