describe('GroupedSelects', function() {
  beforeEach(function() {
    loadFixtures('grouped-select.html');
    $('select').change(function(e) {
      console.log('select changed', this, $('select'));
      GroupedSelects.toggleOptions('select', this);
    });
  });

  it('disables options w/ values w/in the group that match the selected value', function() {
    $('#group_a_1').val('a1');
    $('#group_a_1').change();
    expect($('#group_a_2 option[value="a1"]')).toHaveAttr('disabled','disabled');
    expect($('#group_a_3 option[value="a1"]')).toHaveAttr('disabled','disabled');
  });

  it('enables options when previously selected value is changed', function() {
    $('#group_a_1').val('a2');
    $('#group_a_1').change();
    expect($('#group_a_2 option[value="a2"]')).toHaveAttr('disabled');
    expect($('#group_a_3 option[value="a2"]')).toHaveAttr('disabled');
    $('#group_a_1').val('a3');
    $('#group_a_1').change();
    expect($('#group_a_2 option[value="a2"]')).not.toHaveAttr('disabled');
    expect($('#group_a_3 option[value="a2"]')).not.toHaveAttr('disabled');
  });
});