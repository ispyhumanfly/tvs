require(["dojo/_base/fx",
    "dojo/dom",
    "dojo/dom-style",
    "dojo/query",
    "dojo/dom-construct"],

function (fx, dom, style, query, construct) {

    var curtain = query("#curtain")[0];

    fx.fadeOut({
        node: curtain,
        duration: 1000,
        onEnd: function () {

            construct.destroy("curtain");
        }

    }).play(1000);
});