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
        DiscourseGitter::Gitter.set_rule(topic.category.id, integration[:room], 'mute')
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
          DiscourseGitter::Gitter.set_rule(topic.category.id, integration[:room], 'follow')
        end

        it 'does not notify' do
          notified_rooms = DiscourseGitter::Gitter.notify(post2.id)
          expect(notified_rooms).not_to include(integration[:room])
        end
      end

      context 'when filter is watch' do
        before(:each) do
          DiscourseGitter::Gitter.set_rule(topic.category.id, integration[:room], 'watch')
        end

        it 'does notify' do
          notified_rooms = DiscourseGitter::Gitter.notify(post2.id)
          expect(notified_rooms).to include(integration[:room])
        end
      end
    end

    context 'when category is all' do
      before(:each) do
        DiscourseGitter::Gitter.set_rule(nil, integration[:room], 'watch')
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
    # tag cases:
    # 1) existent: { tags: [], filter: 'follow', ... }
    #    new:      { tags: [], filter: 'watch', ... }
    #
    # 2) existent: { tags: [a, b], filter: 'follow', ... }
    #    new:      { tags: [], filter: 'mute', ... }
    #
    # 3) existent: { tags: [], filter: 'follow', ... }
    #    new:      { tags: [a, b], filter: 'mute', ... }
    #
    # 4) existent: { tags: [a, b, c], filter: 'follow', ... }
    #    new:      { tags: [a, b], filter: 'watch', ... }
    #
    # 5) existent: { tags: [a, b], filter: 'follow', ... }
    #    new:      { tags: [a, b, c], filter: 'watch', ... }
    #
    # 6) existent: { tags: [a, b, c], filter: 'follow', ... }
    #    new:      { tags: [a, b, c], filter: 'follow', ... }
    #
    # 7) existent: { tags: [a, b], filter: 'follow', ... }
    #    new:      { tags: [b, c], filter: 'mute', ... }
    #

    let(:tag_names) { Fabricate.times(3, :tag).map(&:name) }

    context 'when case 1' do
      before(:each) do
        DiscourseGitter::Gitter.set_rule(category.id, integration[:room], 'follow')
      end

      it 'overrides the existent rule' do
        DiscourseGitter::Gitter.set_rule(category.id, integration[:room], 'watch')
        rules = DiscourseGitter::Gitter.get_rules(category.id)
        expect(rules.count { |r| r[:room] == integration[:room] }).to eq(1)
        expect(rules.index { |r| r[:room] == integration[:room] && r[:filter] == 'watch' }).not_to be_nil
      end
    end

    context 'when case 2' do
      before(:each) do
        DiscourseGitter::Gitter.set_rule(category.id, integration[:room], 'follow', tag_names)
      end

      it 'creates a new rule' do
        DiscourseGitter::Gitter.set_rule(category.id, integration[:room], 'follow')
        rules = DiscourseGitter::Gitter.get_rules(category.id)
        expect(rules.count { |r| r[:room] == integration[:room] }).to eq(2)
        expect(rules.count { |r| r[:room] == integration[:room] && r[:tags] == [] }).to eq(1)
      end
    end

    context 'when case 3' do
      before(:each) do
        DiscourseGitter::Gitter.set_rule(category.id, integration[:room], 'follow')
      end

      it 'creates a new rule' do
        DiscourseGitter::Gitter.set_rule(category.id, integration[:room], 'follow', tag_names)
        rules = DiscourseGitter::Gitter.get_rules(category.id)
        expect(rules.count { |r| r[:room] == integration[:room] }).to eq(2)
        expect(rules.count { |r| r[:room] == integration[:room] && r[:tags] == tag_names }).to eq(1)
      end
    end

    context 'when case 4' do
      before(:each) do
        DiscourseGitter::Gitter.set_rule(category.id, integration[:room], 'follow', tag_names)
      end

      it 'neither creates or modifies a rule' do
        DiscourseGitter::Gitter.set_rule(category.id, integration[:room], 'watch', tag_names[0..1])
        rules = DiscourseGitter::Gitter.get_rules(category.id)
        expect(rules.count { |r| r[:room] == integration[:room] }).to eq(1)
        expect(rules.count { |r| r[:room] == integration[:room] && r[:filter] == 'follow' }).to eq(1)
      end
    end

    context 'when case 5' do
      before(:each) do
        DiscourseGitter::Gitter.set_rule(category.id, integration[:room], 'follow', tag_names[0..1])
      end

      it 'overrides the rule' do
        DiscourseGitter::Gitter.set_rule(category.id, integration[:room], 'watch', tag_names)
        rules = DiscourseGitter::Gitter.get_rules(category.id)
        expect(rules.count { |r| r[:room] == integration[:room] }).to eq(1)
        expect(rules.count { |r| r[:room] == integration[:room] && r[:tags] == tag_names && r[:filter] == 'watch' }).to eq(1)
      end
    end

    context 'when case 6' do
      before(:each) do
        DiscourseGitter::Gitter.set_rule(category.id, integration[:room], 'follow', tag_names)
      end

      it 'overrides the rule' do
        DiscourseGitter::Gitter.set_rule(category.id, integration[:room], 'watch', tag_names)
        rules = DiscourseGitter::Gitter.get_rules(category.id)
        expect(rules.count { |r| r[:room] == integration[:room] && r[:tags] == tag_names }).to eq(1)
        expect(rules.count { |r| r[:room] == integration[:room] && r[:tags] == tag_names && r[:filter] == 'watch' }).to eq(1)
      end
    end

    context 'when case 7' do
      before(:each) do
        DiscourseGitter::Gitter.set_rule(category.id, integration[:room], 'follow', tag_names[0..1])
      end

      it 'creates a new rule' do
        DiscourseGitter::Gitter.set_rule(category.id, integration[:room], 'watch', tag_names[1..2])
        rules = DiscourseGitter::Gitter.get_rules(category.id)
        expect(rules.count { |r| r[:room] == integration[:room] }).to eq(2)
        expect(rules.count { |r| r[:room] == integration[:room] && r[:tags] == tag_names[1..2] }).to eq(1)
      end
    end
  end

  describe '.delete_filter' do
    before(:each) do
      DiscourseGitter::Gitter.set_rule(category.id, integration[:room], 'follow')
    end

    it 'deletes the filter' do
      DiscourseGitter::Gitter.delete_rule(category.id, integration[:room], 'follow', nil)
      rules = DiscourseGitter::Gitter.get_rules(category.id)
      expect(rules.index { |r| r[:room] == integration[:room] && r[:filter] == 'follow' }).to be_nil
    end
  end

  describe '.delete_integration' do
    let(:category2) { Fabricate(:category) }
    before(:each) do
      DiscourseGitter::Gitter.set_rule(category.id, integration[:room], 'follow')
      DiscourseGitter::Gitter.set_rule(category2.id, integration[:room], 'watch')
      DiscourseGitter::Gitter.set_rule(nil, integration[:room], 'follow')
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
