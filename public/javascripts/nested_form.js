//nestead-form
$('form a.add_nested_fields').live('click', function() {
  // Setup
  var assoc   = $(this).attr('data-association');           // Name of child
  var content = $('#' + assoc + '_fields_blueprint').html(); // Fields template

  // Make the context correct by replacing new_<parents> with the generated ID
  // of each of the parent objects
  var context = ($(this).closest('.fields').find('input:first').attr('name') || '').replace(new RegExp('\[[a-z]+\]$'), '');

  // context will be something like this for a brand new form:
  // project[tasks_attributes][1255929127459][assignments_attributes][1255929128105]
  // or for an edit form:
  // project[tasks_attributes][0][assignments_attributes][1]


  if(context) {
    var parent_names = context.match(/[a-z_]+_attributes/g) || [];
    var parent_ids   = context.match(/[0-9]+/g);


    for(i = 0; i < parent_names.length; i++) {
      if(parent_ids[i]) {
        content = content.replace(
          new RegExp('(\\[' + parent_names[i] + '\\])\\[.+?\\]', 'g'),
          '$1[' + parent_ids[i] + ']'
        )
      }
    }
  }

  // Make a unique ID for the new child
  var regexp  = new RegExp('new_' + assoc, 'g');
  var new_id  = new Date().getTime();
  content     = content.replace(regexp, new_id);

  if(assoc == "questions"){
    $(this).parent().siblings('questions').append(content);
  }
  else if(assoc == "notes"){
    $(this).parent().siblings('notes').append(content);
  }
  else if(assoc == "transfers"){
  $($('.transfers_fields').parent()).show();
  $('.transfers_fields').append(content)
  }
  else
  {
    $(this).before(content);
  }

  count = 1
  if($(this).attr('type') == 'notes'){
    $.each($('.fields:visible'), function(){
      if($(this).find('nested_type').attr('type') == 'notes'){
        $(this).find('legend').text("Note "+count++);
      }
    });
  }
  if($(this).attr('type') == 'questions'){
    $.each($('.fields:visible'), function(){
      if($(this).find('nested_type').attr('type') == 'questions'){
        $(this).find('legend').text("Question "+count++);
    $(this).find('.remove_nested_fields').attr("answered","false");
      }
    });
    $(this).parent().siblings('questions').find('.fields:visible').last().find('a.add_nested_fields').trigger('click')
  }

  if($(this).attr('type') == 'possible_responses'){
    if($(this).siblings('div.fields').length == 1){
      $(this).siblings('div.fields').find('input').first().val('No response');
    }
    $.each($(this).siblings('div.fields:visible'), function(){
      $(this).find('input').slice(1,2).val(count++ );
    $(this).find('.remove_nested_fields').attr("answered","false");
    });
  }
  return false;
});


// remove the nested fields
$('form a.remove_nested_fields').live('click', function() {
  if($(this).attr('type') == 'questions'){
  if($(this).attr('answered') == 'true'){
    alert("You cannot delete this question as it has already been answered.");
    return false;
  }
    if($('.fields:visible').find('nested_type[type=questions]').length == 1){
      alert("You must have at least one question");
      return false;
    }
  }

  if($(this).attr('type') == 'possible_responses'){
  if($(this).attr('answered') == 'true'){
    alert("You cannot delete this response as it already has an answer recorded.");
    return false;
  }

    if($(this).parents('div.fields').first().siblings('div.fields:visible').length == 0){
      alert("You must have at least one response.");
      return false;
    }
  }

  var hidden_field = $(this).prev('input[type=hidden]')[0];
  if(hidden_field) {
    hidden_field.value = '1';
  }
  $(this).closest('.fields').hide();


  count = 1
  if($(this).attr('type') == 'notes'){
    $.each($('.fields:visible'), function(){
      if($(this).find('nested_type').attr('type') == 'notes'){
        $(this).find('legend').text("Note "+count++);
      }
    });
  }
  if($(this).attr('type') == 'questions'){
    $.each($('.fields:visible'), function(){
      if($(this).find('nested_type').attr('type') == 'questions'){
        $(this).find('legend').text("Question "+count++);
      }
    });
  }
  if($(this).attr('type') == 'possible_responses'){
    $.each($(this).parents('div.fields').first().siblings('div.fields:visible'), function(){
      $(this).find('input').slice(1,2).val(count++ )
    });
  }
  return false;
});
});



