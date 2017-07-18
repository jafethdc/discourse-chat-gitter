import { acceptance } from 'helpers/qunit-helpers';

acceptance('Gitter chat', {
  loggedIn: true,

  beforeEach(){
    const response = (object) => { return [200, {"Content-Type": "text/html; charset=utf-8"}, object] };

    server.get('/gitter/integrations.json', () => {
      return response({ integrations:
        [
          { room: 'gitterhq/meta', webhook: 'http://gitter.com/webhook', room_id: 'o39uh20ddda',
            rules: [ {category_id: null, room: 'gitterhq/meta', filter: 'watch'},
                    {category_id: null, room: 'gitterhq/meta', tags: ['plugins', 'dev'], filter: 'mute'}]
          },
          { room: 'gitterhq/api', webhook: 'http://gitter.com/webhook', room_id: 'o39uh20d5r3d',
            rules: [ {category_id: null, room: 'gitterhq/api', filter: 'mute'},
              {category_id: null, room: 'gitterhq/api', tags: ['pr-welcome'], filter: 'follow'}]
          }
        ]
      });
    });

    server.post('/gitter/integrations.json', () => { return response({}); });
  }
});

test('Integrations load successfully', assert => {
  visit('/admin/plugins/gitter');

  andThen(() => {
    assert.equal(find('.admin-plugin-gitter .integration-item').length, 2);
  });
});

test('Add integration works', assert => {
  visit('/admin/plugins/gitter');

  fillIn('.room', 'community/aroom');
  fillIn('.webhook', 'http://gitter.com/other_webhook');
  click('.save-integration');

  andThen(() => {
    assert.equal(find('.admin-plugin-gitter .integration-item').length, 3);
  });
});
