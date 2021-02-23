'use strict';

$(function() {
    function linkFormat(dataFormat, name, id) {
        const base = window.location.origin;
        return dataFormat
            .replace('{name}', name)
            .replace('{id}', id)
            .replace('{base}', base);
    }

    function showLink(linkElement, name, id) {
        console.log("Show link");
        const dataFormat = linkElement.attr('data-format');
        const address = linkFormat(dataFormat, encodeURI(name), id);
        const text = linkFormat(dataFormat, name, id);
        linkElement.removeClass("disabled");
        linkElement.attr('href', address);
        linkElement.text(text);
    }

    function hideLink(linkElement) {
        console.log("Hide link");
        const base = window.location.origin;
        linkElement.addClass("disabled");
        linkElement.removeAttr('href');
        linkElement.text(linkElement.attr('data-format').replace("{base}", base));
    }

    function update() {
        console.log("Update");
        const name = $('#boxes #name').val();
        const id = $('#boxes #id').val();
        $('.resource').each(function() {
            if ($(this).attr('data-format').includes("{name}")) {
                if ($(this).attr('data-format').includes("{id}")) {
                    (name && id) ? showLink($(this), name, id) : hideLink($(this));
                } else {
                    (name) ? showLink($(this), name, id) : hideLink($(this));
                }
            } else {
                if ($(this).attr('data-format').includes("{id}")) {
                    (id) ? showLink($(this), name, id) : hideLink($(this));
                } else {
                    showLink($(this), name, id);
                }
            }
        });
    }

    $('#name').on('input propertychange paste', update);
    $('#id').on('input propertychange paste', update);
    $('#name').focus();
    update();
});
