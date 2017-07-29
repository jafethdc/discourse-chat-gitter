require 'rails_helper'

RSpec.describe GitterBot do
  let!(:intgr) { DiscourseGitter::Gitter.set_integration('comm/room1', '123', 'http://gitter.com/webhook') }
  let!(:intgr2) { DiscourseGitter::Gitter.set_integration('comm/room2', '456', 'http://gitter.com/webhook') }
  let!(:category) { Fabricate(:category) }
  let!(:tags_names) { Fabricate.times(3, :tag).map(&:name) }

  before do
    SiteSetting.gitter_enabled = true
    SiteSetting.tagging_enabled = true
    GitterBot.stubs(:fetch_rooms).returns([{ 'name'=>intgr[:room], 'id'=>intgr[:room_id] }, { 'name'=>intgr2[:room], 'id'=>intgr2[:room_id] }])
    SiteSetting.gitter_command_users = 'rogerwaters, thomyorke, robinpecknold'
    stub_request(:post, %r{https://api.gitter.im/v1/rooms/.+/chatMessages}).to_return(status: 200)
  end

  describe '.init' do
    context 'when gitter bot setting is not enabled' do
      it "won't run the bot" do
        GitterBot.init
        sleep(5)
        expect(GitterBot.running?).to be_falsey
      end
    end

    context 'when gitter bot setting is enabled' do
      before(:each) do
        GitterBotUserTokenValidator.any_instance.stubs(:valid_value?).with('gitterbot123').returns(true)
        SiteSetting.gitter_bot_user_token = 'gitterbot123'
        SiteSetting.gitter_bot_enabled = true
      end

      it 'runs the bot' do
        GitterBot.init
        sleep(5)
        expect(GitterBot.running?).to be_truthy
      end

      after(:each) { GitterBot.stop }
    end
  end

  describe '.status_message'

  describe '.handle_add_rule' do
    context 'when category is passed but tags are not' do
      it 'calls set_rule with the proper params' do
        DiscourseGitter::Gitter.expects(:set_rule).with(category.id, intgr[:room], 'watch', [])
        GitterBot.handle_add_rule(intgr[:room], 'watch', category.name)
      end
    end

    context 'when no category is passed but tags are' do
      it 'calls set_rule with the proper params' do
        DiscourseGitter::Gitter.expects(:set_rule).with(nil, intgr[:room], 'follow', tags_names)
        GitterBot.handle_add_rule(intgr[:room], 'follow', "tags: #{tags_names.join(',')}")
      end
    end

    context 'when category and tags are passed' do
      context 'when all the tags exist' do
        it 'calls set_rule with the proper params' do
          DiscourseGitter::Gitter.expects(:set_rule).with(category.id, intgr[:room], 'watch', tags_names)
          GitterBot.handle_add_rule(intgr[:room], 'watch', "#{category.name} tags: #{tags_names.join(',')}")
        end
      end

      context 'when not all the tags exist' do
        it 'calls send_message with the proper params' do
          tags_names.push 'awesometag'
          GitterBot.expects(:send_message).with(intgr[:room_id], I18n.t('gitter.bot.nonexistent_tags', tags: ['awesometag']))
          GitterBot.handle_add_rule(intgr[:room], 'watch', "#{category.name} tags: #{tags_names.join(',')}")
        end
      end

      context 'when category does not exist' do
        it 'calls send_message with the proper params' do
          GitterBot.expects(:send_message).with(intgr[:room_id], I18n.t('gitter.bot.nonexistent_category', category: 'catabc'))
          GitterBot.handle_add_rule(intgr[:room], 'watch', 'catabc')
        end
      end
    end
  end

  describe '.handle_remove_rule' do
    before(:each) do
      DiscourseGitter::Gitter.set_rule(category.id, intgr[:room], 'mute')
      DiscourseGitter::Gitter.set_rule(nil, intgr[:room], 'watch')
    end

    context 'when index is out of bound' do
      it 'calls delete_rule with proper params'

      it 'calls send message with proper params' do
        GitterBot.expects(:send_message).with(intgr[:room_id], I18n.t('gitter.bot.nonexistent_rule'))
        GitterBot.handle_remove_rule(intgr[:room], 5)
      end
    end

    context 'when index is within bound' do
      it 'calls send message with proper params' do
        # expect remove_rule is called
        GitterBot.expects(:send_message).with(intgr[:room_id], regexp_matches(/#{I18n.t('gitter.bot.status_title')}/))
        GitterBot.handle_remove_rule(intgr[:room], 0)
      end
    end
  end

  describe '.permitted_users' do
    it { expect(GitterBot.permitted_users).to include('thomyorke') }
  end

  describe '.handle_message' do
    context 'when the sender is not in the permitted list' do
      let(:message) { gitter_message('/discourse status', 'kendricklamar') }

      it 'calls send_message with the proper params' do
        GitterBot.expects(:send_message).with(intgr[:room_id], I18n.t('gitter.bot.unauthorized_user', user: 'kendricklamar'))
        GitterBot.handle_message(message, intgr[:room], intgr[:room_id])
      end
    end

    context 'when /discourse randomcommand is passed' do
      let(:message) { gitter_message('/discourse arandomcommand', 'thomyorke') }

      it 'calls send_message with the proper params' do
        GitterBot.expects(:send_message).with(intgr[:room_id], I18n.t('gitter.bot.nonexistent_command'))
        GitterBot.handle_message(message, intgr[:room], intgr[:room_id])
      end
    end

    context 'when /discourse status is passed' do
      let(:message) { gitter_message('/discourse status', 'thomyorke') }

      it 'calls send_message with the proper params' do
        GitterBot.expects(:send_message).with(intgr[:room_id], GitterBot.status_message(intgr[:room]))
        GitterBot.handle_message(message, intgr[:room], intgr[:room_id])
      end
    end

    context 'when /discourse remove is passed' do
      let(:message) { gitter_message('/discourse remove 1', 'thomyorke') }

      it 'calls send_message with the proper params' do
        GitterBot.expects(:handle_remove_rule).with(intgr[:room], '1')
        GitterBot.handle_message(message, intgr[:room], intgr[:room_id])
      end
    end
  end
end


def gitter_message(text, username)
  { 'model' => { 'text' => text, 'fromUser' => { 'username' => username } } }
end
