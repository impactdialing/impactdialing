GroupedSelects = {
  toggleOptions: function(selector, el) {
    var selectedID = $(el).attr('id'),
        selectedValue = $(el).val(),
        selectedValues = $(selector).map(function() {
          return $(this).val();
        });
    /**
      Disable selected option from other select menus.
    */
    $(selector).not('#'+selectedID).each(function() {
      if( selectedValue.length > 0 ) {
        $(this).find('option[value="'+selectedValue+'"]').attr('disabled', 'disabled');
      }
    });
    /**
      Enable de-selected option for all select menus it was disabled for.
    */
    $(selector+' option[disabled="disabled"]').each(function() {
      var curValue = $(this).attr('value');
      var isSelected = $.inArray(curValue, selectedValues);
      if( isSelected === -1 ) {
        $(this).removeAttr('disabled');
      }
    });
  }
};
