import componentTest from 'helpers/component-test';
import Integration from 'discourse/plugins/discourse-chat-gitter/discourse/models/integration';
import FilterRule from 'discourse/plugins/discourse-chat-gitter/discourse/models/filter-rule';

moduleForComponent('integration-item', { integration: true });

// this.siteSettings.tagging_enabled = true;

const filters = [
  { id: 'watch', name: 'watch', icon: 'exclamation-circle' },
  { id: 'follow', name: 'follow', icon: 'circle'},
  { id: 'mute', name: 'mute', icon: 'times-circle' }
];

const response = (object) => { return [200, {"Content-Type": "text/html; charset=utf-8"}, object] };

componentTest('it renders all the filter rules', {
  template: `{{integration-item integration=integration filters=filters}}`,

  beforeEach(){
    const integration = Integration.create({
      room: 'gitterhq/meta',
      webhook: 'http://gitter.com/webhook',
      room_id: 'o39uh20ddda',
      rules: [ FilterRule.create({category_id: null, room: 'gitterhq/meta', filter: 'watch'}),
        FilterRule.create({category_id: null, room: 'gitterhq/meta', tags: ['plugins', 'dev'], filter: 'mute'})]
    });
    this.set('integration', integration);
    this.set('filters', filters);
    this.siteSettings.tagging_enabled = true;
  },

  test(assert){
    assert.equal(this.$('.filter-rule').length, 2);
    assert.equal(this.$('.filter-rule').eq(1).find('td').eq(1).text(), 'plugins,dev');
  }
});

componentTest('it adds a filter', {
  template: `{{integration-item integration=integration filters=filters}}`,

  beforeEach(){
    this.set('integration', Integration.create({
      room: 'gitterhq/meta',
      webhook: 'http://gitter.com/webhook',
      room_id: 'o39uh20ddda'
    }));
    this.set('filters', filters);

    server.post('/gitter/filter_rules.json', () => { return response({}); });
    this.siteSettings.tagging_enabled = true;
  },


  test(assert){
    andThen(() => {
      console.log(this.get('editingRule'));
    });
    click('.save-new-rule');
    andThen(() => {
      assert.equal(this.$('.filter-rule').length, 1);
      assert.equal(this.$('.filter-rule td').eq(2).text(), 'All posts and replies');
    });
  }
});


componentTest('test removing an integration', {
  template: `{{integration-item integration=integration filters=filters}}`,

  beforeEach(){
    const integration = Integration.create({
      room: 'gitterhq/meta',
      webhook: 'http://gitter.com/webhook',
      room_id: 'o39uh20ddda',
      rules: [ FilterRule.create({category_id: null, room: 'gitterhq/meta', filter: 'watch'}),
        FilterRule.create({category_id: null, room: 'gitterhq/meta', tags: ['plugins', 'dev'], filter: 'mute'})]
    });
    this.set('integration', integration);
    this.set('filters', filters);

    server.delete('/gitter/filter_rules.json', () => { return response({}); });
    this.siteSettings.tagging_enabled = true;
  },

  test(assert){
    click('.delete-rule:first-child');
    andThen(() => {
      assert.equal(this.$('.filter-rule').length, 1);
    });
  }
});
