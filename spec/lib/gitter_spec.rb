require 'rails_helper'

RSpec.describe DiscourseGitter::Gitter do

  before do
    SiteSetting.gitter_enabled = true
    SiteSetting.tagging_enabled = true
  end

  let!(:category) { Fabricate(:category) }
  let!(:topic) { Fabricate(:topic, category_id: category.id) }
  let!(:integration) { DiscourseGitter::Gitter.set_integration('comm/room1', '123', 'http://gitter.com/webhook') }

  describe '.notify' do
    before do
      stub_request(:post, 'http://gitter.com/webhook').to_return(body: 'OK')
    end

    context 'when a filter is mute' do
      before(:each) do
        DiscourseGitter::Gitter.set_filter(topic.category.id, integration[:room], 'mute')
      end

      let(:post) { Fabricate(:post, topic: topic) }

      it 'does not notify' do
        notified_rooms = DiscourseGitter::Gitter.notify(post.id)
        expect(notified_rooms).not_to include(integration[:room])
      end
    end

    context 'when second post is created' do
      let!(:post1) { Fabricate(:post, topic: topic) }
      let(:post2) { Fabricate(:post, topic: topic) }

      context 'when filter is follow' do
        before(:each) do
          DiscourseGitter::Gitter.set_filter(topic.category.id, integration[:room], 'follow')
        end

        it 'does not notify' do
          notified_rooms = DiscourseGitter::Gitter.notify(post2.id)
          expect(notified_rooms).not_to include(integration[:room])
        end
      end

      context 'when filter is watch' do
        before(:each) do
          DiscourseGitter::Gitter.set_filter(topic.category.id, integration[:room], 'watch')
        end

        it 'does notify' do
          notified_rooms = DiscourseGitter::Gitter.notify(post2.id)
          expect(notified_rooms).to include(integration[:room])
        end
      end
    end

    context 'when category is all' do
      before(:each) do
        DiscourseGitter::Gitter.set_filter(nil, integration[:room], 'watch')
      end

      it 'notifies any guardian-visible post' do
        topic = Fabricate(:topic)
        post = Fabricate(:post, topic: topic)
        notified_rooms = DiscourseGitter::Gitter.notify(post.id)
        expect(notified_rooms).to include(integration[:room])
      end
    end
  end

  describe '.set_filter' do
    # cases:
    # 1) existent: { category: 1, tags: [], room: 'comm/room1', filter: 'follow' }
    #    new: { category: 1, tags: [], room: 'comm/room1', filter: 'watch' }
    # 2) existent: { category: 1, tags: [], room: 'comm/room1', filter: 'follow' }
    #    new: { category: 1, tags: [tag1, tag2], room: 'comm/room1', filter: 'follow' }
    # 3) existent: { category: 1, tags: [tag1, tag2], room: 'comm/room1', filter: 'follow' }
    #    new: { category: 1, tags: [tag2, tag3], room: 'comm/room1', filter: 'follow' }

    context 'when case 1' do
      before(:each) do
        DiscourseGitter::Gitter.set_filter(category.id, integration[:room], 'follow')
      end

      it 'overrides the existent rule' do
        DiscourseGitter::Gitter.set_filter(category.id, integration[:room], 'watch')
        rules = DiscourseGitter::Gitter.get_filters(category.id)
        expect(rules.count { |r| r[:room] == integration[:room] }).to eq(1)
        expect(rules.index { |r| r[:room] == integration[:room] && r[:filter] == 'watch' }).not_to be_nil
      end
    end

    context 'when case 2' do
      let(:tags) { Fabricate.times(2, :tag) }

      before(:each) do
        DiscourseGitter::Gitter.set_filter(category.id, integration[:room], 'follow')
      end

      it 'overrides the existent rule' do
        tag_names = tags.map(&:name)
        DiscourseGitter::Gitter.set_filter(category.id, integration[:room], 'follow', tag_names)
        rules = DiscourseGitter::Gitter.get_filters(category.id)
        expect(rules.count { |r| r[:room] == integration[:room] && r[:filter] == 'follow' }).to eq(1)
        expect(rules.index { |r| r[:room] == integration[:room] && r[:tags] == tag_names && r[:filter] == 'follow' }).not_to be_nil
      end
    end

    context 'when case 3' do
      let(:tags) { Fabricate.times(3, :tag) }

      before(:each) do
        DiscourseGitter::Gitter.set_filter(category.id, integration[:room], 'follow', tags[0..1].map(&:name))
      end

      it 'creates a new rule' do
        DiscourseGitter::Gitter.set_filter(category.id, integration[:room], 'follow', tags[1..2].map(&:name))
        rules = DiscourseGitter::Gitter.get_filters(category.id)
        expect(rules.count { |r| r[:room] == integration[:room] && r[:filter] == 'follow' }).to eq(2)
      end
    end
  end

  describe '.delete_filter' do
    before(:each) do
      DiscourseGitter::Gitter.set_filter(category.id, integration[:room], 'follow')
    end

    it 'deletes the filter' do
      DiscourseGitter::Gitter.delete_filter(category.id, integration[:room], 'follow', nil)
      rules = DiscourseGitter::Gitter.get_filters(category.id)
      expect(rules.index { |r| r[:room] == integration[:room] && r[:filter] == 'follow' }).to be_nil
    end
  end

  describe '.delete_integration' do
    let(:category2) { Fabricate(:category) }
    before(:each) do
      DiscourseGitter::Gitter.set_filter(category.id, integration[:room], 'follow')
      DiscourseGitter::Gitter.set_filter(category2.id, integration[:room], 'watch')
      DiscourseGitter::Gitter.set_filter(nil, integration[:room], 'follow')
    end

    it 'deletes the integration' do
      DiscourseGitter::Gitter.delete_integration(integration[:room])
      expect(PluginStore.get(DiscourseGitter::PLUGIN_NAME, "integration_#{integration[:room]}")).to be_nil
    end

    it 'deletes the integrations rules' do
      DiscourseGitter::Gitter.delete_integration(integration[:room])
      integration_rules = PluginStoreRow.where(plugin_name: DiscourseGitter::PLUGIN_NAME).where('key LIKE ?', 'category_%').inject(0) do |sum, row|
        sum + PluginStore.cast_value(row.type_name, row.value).count { |rule| rule[:room] == integration[:room] }
      end
      expect(integration_rules).to eq(0)
    end
  end
end
