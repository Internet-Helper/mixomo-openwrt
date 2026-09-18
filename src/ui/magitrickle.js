'use strict';
'require view';

return view.extend({
    handleSaveApply: null,
    handleSave: null,
    handleReset: null,

    render: function() {
        var ip = window.location.hostname;
        var url = 'http://' + ip + ':8080';
        return E('div', {
            style: 'width:100%; height:92vh; margin: -20px -20px 0 -20px; overflow: hidden;'
        }, E('iframe', {
            src: url,
            style: 'width:100%; height:100%; border: none;'
        }));
    }
});