import FilterRule from 'discourse/plugins/discourse-chat-gitter/discourse/models/filter-rule';
import Integration from 'discourse/plugins/discourse-chat-gitter/discourse/models/integration';
import { ajax } from 'discourse/lib/ajax'

export default Discourse.Route.extend({
  model(){
    return ajax("/gitter/integrations.json").then(result => {
      return result.integrations.map(integration => {
        integration.filters = integration.filters.map(filter => {
          return FilterRule.create(filter);
        });
        console.log('integration', integration);
        return Integration.create(integration);
      });
    });

/*
    let integrations = [
      {
        room: 'gitter/hq',
        webhook: 'https://webhooks.gitter.im/e/2g4c4adf4a8c2b52789d',
        room_id: '58b7b451d73408ce4f4dd8d4'
      },
      {
        room: 'quire/api',
        webhook: 'https://webhooks.gitter.im/e/29fe02df4a8c2b52789d',
        room_id: '58b7b451d73408ce4f49fsua'
      }
    ];

    let result = {};

    integrations.forEach((i) => {
      result[i.room] = Integration.create(i);
    });

    let filters= [
      {
        category_id: 3,
        room: 'gitter/hq',
        filter: 'mute',
        tags: [
          'pr-welcome',
          'discourse'
        ]
      },

      {
        category_id: 4,
        room: 'quire/api',
        filter: 'watch',
        tags: [
          'whatup',
          'discussion'
        ]
      },

      {
        category_id: 2,
        room: 'quire/api',
        filter: 'watch',
        tags: [
          'whatup',
          'discourse'
        ]
      },

      {
        category_id: 4,
        room: 'gitter/hq',
        filter: 'follow',
        tags: [
          'meta',
          'marketplace'
        ]
      }
    ];

    filters.forEach((f) => {
      result[f.room].filters.push(FilterRule.create(f));
    });
    return Object.values(result);
*/
  }
});
