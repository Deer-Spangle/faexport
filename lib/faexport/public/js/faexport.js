'use strict';

$(function() {
    function update() {
        var name = $('#boxes #name').val();
        var id = $('#boxes #id').val();
        if (name || id) {
            if (!name) { name = "{name}"; }
            if (!id) { id = "{id}"; }
            $('#links').show();
            $('.resource').each(function() {
                var link = $(this).attr('data-format').replace('{name}', name)
                                                      .replace('{id}', id);
                $(this).attr('href', link);
                $(this).children('span.name').text(name);
                $(this).children('span.id').text(id);
            });
        } else {
            $('#links').hide();
        }
    }

    $('#name').on('input propertychange paste', update);
    $('#id').on('input propertychange paste', update);
    $('#name').focus();
});
