/* ============================================================ 
    All of the aplication's custom javascript scripts goes here
   ============================================================

Author: Andrei Cacio
Email: andrei.cacio@evozon.com

*/

// Auto switch the bootstrap switcer on the Settings page.

$(document).ready(function(){
    var simplemde = new SimpleMDE();

	var state = $('#social_media_state').val();
	state = parseInt(state);

	$('.make-switch').bootstrapSwitch('setState' , state);

});

// Activate the tag input

$(document).ready(function() {

	$.getJSON('/api/tags.json', function(tags_list) {
		$("#tags").select2({tags: tags_list});
	});
	
});
