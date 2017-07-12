require 'rails_helper'

describe 'Gitter', type: :request do
  before do
    SiteSetting.gitter_enabled = true
  end

  let!(:category) { Fabricate(:category) }
  let!(:topic) { Fabricate(:topic, category_id: category.id) }
  let!(:admin) { Fabricate(:admin) }
  let!(:integration) { DiscourseGitter::Gitter.set_integration('comm/room1', '123', 'http://gitter.com/webhook') }
  let!(:tags) { Fabricate.times(3, :tag) }

  shared_examples 'admin constraints' do |action, route|
    context 'when users is not signed in' do
      it 'raises the right error' do
        expect { send(action, route) }.to raise_error(ActionController::RoutingError)
      end
    end

    context 'when user is not an admin' do
      it 'should raise the right error' do
        sign_in(Fabricate(:user))
        expect { send(action, route) }.to raise_error(ActionController::RoutingError)
      end
    end
  end

  describe 'viewing integrations' do
    include_examples 'admin constraints', :get, '/gitter/integrations.json'

    before do
      DiscourseGitter::Gitter.set_rule(topic.category.id, integration[:room], 'follow')
    end

    context 'as an admin' do
      before { sign_in(admin) }

      it 'returns the right response' do
        get '/gitter/integrations.json'
        expect(response).to be_success
        integrations = JSON.parse(response.body)['integrations']
        expect(integrations.count).to eq(1)
      end
    end
  end

  describe 'adding an integration' do
    include_examples 'admin constraints', :post, '/gitter/integrations.json'

    context 'as an admin' do
      before { sign_in(admin) }

      it 'adds a new integration' do
        post '/gitter/integrations.json', room: 'aroom', room_id: 'aroomid', webhook: 'awebhook'
        expect(JSON.parse(response.body)).to eq('success' => 'OK')

        integrations = DiscourseGitter::Gitter.get_integration('aroom')
        expect(integrations).not_to be_nil
      end
    end
  end

  describe 'removing an integration' do
    include_examples 'admin constraints', :delete, '/gitter/integrations.json'

    before do
      DiscourseGitter::Gitter.set_rule(topic.category.id, integration[:room], 'follow')
    end

    context 'as an admin' do
      before { sign_in(admin) }

      it 'removes the specified integration' do
        delete '/gitter/integrations.json', room: integration[:room]
        expect(JSON.parse(response.body)).to eq('success' => 'OK')

        room = PluginStore.get(DiscourseGitter::PLUGIN_NAME, "integration_#{integration[:room]}")
        expect(room).to be_nil
      end
    end

  end

  describe 'adding a filter rule' do
    include_examples 'admin constraints', :post, '/gitter/filter_rules.json'

    context 'as an admin' do
      before { sign_in(admin) }

      it 'adds a new filter rule' do
        filter_data = { category_id: category.id, filter: 'watch', room: integration[:room], tags: tags.map(&:name) }
        post '/gitter/filter_rules.json', filter_data
        expect(JSON.parse(response.body)).to eq('success' => 'OK')

        filters = DiscourseGitter::Gitter.get_rules(category.id)
        expect(filters.index(filter_data.except(:category_id).stringify_keys)).not_to be_nil
      end
    end
  end

  describe 'removing a filter rule' do
    include_examples 'admin constraints', :post, '/gitter/filter_rules.json'

    before do
      DiscourseGitter::Gitter.set_rule(topic.category.id, integration[:room], 'follow')
    end

    context 'as an admin' do
      before { sign_in(admin) }

      it 'removes the specified filter rule' do
        filter_data = { category_id: category.id, room: integration[:room], filter: 'follow', tags: [] }
        delete '/gitter/filter_rules.json', filter_data
        expect(JSON.parse(response.body)).to eq('success' => 'OK')

        filters = DiscourseGitter::Gitter.get_rules(category.id)
        expect(filters.index(filter_data.except(:category_id).stringify_keys)).to be_nil
      end
    end
  end
end
