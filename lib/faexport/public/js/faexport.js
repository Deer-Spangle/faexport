'use strict';

$(function() {
    function update() {
        var name = $('#boxes #name').val();
        var id = $('#boxes #id').val();
        var base = window.location.origin;
        if (name || id) {
            if (!name) { name = "{name}"; }
            if (!id) { id = "{id}"; }
            $('#links').show();
            $('.resource').each(function() {
                var link = $(this).attr('data-format').replace('{name}', encodeURI(name))
                                                      .replace('{id}', id)
                                                      .replace('{base}', base);
                $(this).attr('href', link);
                $(this).text(link);
            });
        } else {
            $('#links').hide();
        }
    }

    $('#name').on('input propertychange paste', update);
    $('#id').on('input propertychange paste', update);
    $('#name').focus();
});
