import FilterRule from 'discourse/plugins/discourse-chat-gitter/discourse/models/filter-rule';
import { ajax } from 'discourse/lib/ajax';
import { popupAjaxError } from 'discourse/lib/ajax-error';

export default Ember.Component.extend({
  classNames: ['integration-item'],

  testingNotification: false,

  init(){
    this._super();
    this.set('editingFilter', FilterRule.create({}));
  },

  arrayDiff(array1, array2){
    return array1.filter(x => array2.indexOf(x) < 0);
  },

  arrayUniq(array){
    return array.filter((v, i, a) => a.indexOf(v) === i);
  },

  actions: {
    deleteFilter(filter){
      ajax('/gitter/filter_rules.json', {
        method: 'DELETE',
        data: filter.getProperties('category_id', 'filter', 'room', 'tags')
      }).then(()=>{
        this.get('integration.filters').removeObject(filter);
      }).catch(popupAjaxError);
    },

    saveFilter(){
      const data = Object.assign(this.get('editingFilter').getProperties('filter', 'category_id', 'tags'),
                                 this.get('integration').getProperties('room'));
      ajax('/gitter/filter_rules.json', {
        method: 'POST',
        data: data
      }).then(() => {
        let overridingRule = null;
        const editingRule = this.get('editingFilter');
        for(let i=0; i<this.get('integration.filters.length'); i++){
          let rule = this.get('integration.filters').objectAt(i);
          if(rule.get('categoryName') !== editingRule.get('categoryName')) continue;

          if(rule.get('tags.length') === 0){
            if(editingRule.get('tags.length') === 0){
              overridingRule = rule;
              break;
            }
          }else{
            if(editingRule.get('tags.length') === 0) continue;
            if(this.arrayDiff(rule.get('tags'), editingRule.get('tags')).length === 0){
              overridingRule = rule;
              break;
            }else{
              if(this.arrayDiff(editingRule.get('tags'), rule.get('tags')).length === 0){
                this.set('editingFilter', FilterRule.create({}));
                return;
              }
            }
          }
        }

        if(overridingRule !== null){
          overridingRule.set('filter', editingRule.get('filter'));
          overridingRule.set('tags', this.arrayUniq(overridingRule.get('tags').concat(editingRule.get('tags'))));
        }else{
          this.get('integration.filters').pushObject(FilterRule.create(data));
        }

        this.set('editingFilter', FilterRule.create({}));
      }).catch(popupAjaxError);
    },

    deleteIntegration(){
      this.get('onDelete')(this.get('integration'));
    },

    testNotification(){
      this.set('testingNotification', true);

      ajax('/gitter/test_notification.json', {
        method: 'PUT',
        data: this.get('integration').getProperties('room')
      }).catch(popupAjaxError).finally(() => {
        this.set('testingNotification', false);
      });
    }
  }
});
