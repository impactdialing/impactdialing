(function($) {

  function replace_in_content(content, regexp_str, with_str) {
    reg_exp = new RegExp(regexp_str);
    content.replace(reg_exp, with_str);
  }

  function trigger_removal_callback(node) {
    node.trigger('removal-callback');
  }

  function trigger_after_removal_callback(node) {
    node.parent().trigger('after-removal-callback');
  }


  $('.add_fields').live('click', function(e) {
    e.preventDefault();
    var $this                 = $(this),
        assoc                 = $this.data('association'),
        assocs                = $this.data('associations'),
        content               = $this.data('template'),
        insertionMethod       = $this.data('association-insertion-method') || $this.data('association-insertion-position') || 'before';
        insertionNode         = $this.data('association-insertion-node'),
		siblingClass		  = $this.data('association-insertion-node-sibling-class'),
        regexp_braced         = new RegExp('\\[new_' + assoc + '\\]', 'g'),
        regexp_underscord     = new RegExp('_new_' + assoc + '_', 'g'),
        new_id                = new Date().getTime(),
        newcontent_braced     = '[' + new_id + ']',
        newcontent_underscord = '_' + new_id + '_',
        new_content           = content.replace(regexp_braced, '[' + new_id + ']');

    if (new_content == content) {
        regexp_braced     = new RegExp('\\[new_' + assocs + '\\]', 'g');
        regexp_underscord = new RegExp('_new_' + assocs + '_', 'g');
        new_content       = content.replace(regexp_braced, '[' + new_id + ']');
    }

    new_content = new_content.replace(regexp_underscord, newcontent_underscord);
    if (insertionNode){	  
	   if (insertionNode == "this"){
	      insertionNode = $this	
	   }
	   else if (insertionNode == "sibling") {
		 insertionNode = $($(this).parent().siblings("."+siblingClass)[0])
	    }
	   else {
	     insertionNode = $(insertionNode)	
	   }
     }else {
      insertionNode = $this.parent();
      }

    var contentNode = $(new_content);
    // allow any of the jquery dom manipulation methods (after, before, append, prepend, etc)
    // to be called on the node.  allows the insertion node to be the parent of the inserted
    // code and doesn't force it to be a sibling like after/before does. default: 'before'
    insertionNode[insertionMethod](contentNode);
    $this.parent().trigger('insertion-callback');
    

  });

  $('.remove_fields.dynamic').live('click', function(e) {
    var $this = $(this);
	var removalValidation = $this.data('removal-validation');
    var trigger_node = $this.closest(".nested-fields").parent();
    if (!removalValidation || window[removalValidation](this)){	   
	    trigger_removal_callback(trigger_node);
	    e.preventDefault();
	    $this.closest(".nested-fields").remove();
	    trigger_after_removal_callback(trigger_node);	
    } else {
	
    }
  });

  $('.remove_fields.existing').live('click', function(e) {
    var $this = $(this);
	var removalValidation = $this.data('removal-validation');
    var trigger_node = $this.closest(".nested-fields").parent();
 if (!removalValidation || window[removalValidation](this)){	  
    trigger_removal_callback(trigger_node);
    e.preventDefault();
    $this.prev("input[type=hidden]").val("1");
    $this.closest(".nested-fields").hide();
	$this.closest(".nested-fields").attr('deleted', true);
    trigger_after_removal_callback(trigger_node);
	} else {
	
	}
  });

})(jQuery);