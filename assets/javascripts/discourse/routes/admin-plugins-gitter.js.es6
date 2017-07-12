import FilterRule from 'discourse/plugins/discourse-chat-gitter/discourse/models/filter-rule';
import Integration from 'discourse/plugins/discourse-chat-gitter/discourse/models/integration';
import { ajax } from 'discourse/lib/ajax'

export default Discourse.Route.extend({
  model(){
    return ajax("/gitter/integrations.json").then(result => {
      return result.integrations.map(integration => {
        integration.rules = integration.rules.map(rule => {
          return FilterRule.create(rule);
        });
        return Integration.create(integration);
      });
    });
  }
});
