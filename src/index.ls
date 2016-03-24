{Promise, new-promise, bind-p, return-p, reject-p, from-error-value-callback} = require \./async-p
require! \cheerio
require! \ejs
{read-file} = require \fs
{filter, find, fold, map, obj-to-pairs, pairs-to-obj, reject, Str} = require \prelude-ls
require! \querystring
require! \request

# :: object -> (Response, Body -> a) -> p a
request-p = (request-options) ->
    resolve, reject <- new-promise
    err, response, body <- request request-options
    if err then reject err else resolve {response, body}

# :: String -> String -> String -> p SharePointClient
module.exports = (endpoint, username, password) ->

    # get the security-token-request xml template
    security-token-request-xml-template <- bind-p do 
        (from-error-value-callback read-file) do 
            "#__dirname/security-token-request.ejs"
            \utf8

    # get security-token-request-xml by substituting credentials
    security-token-request-xml = ejs.render security-token-request-xml-template, {endpoint, username, password}
    
    # get the security token (wrapped in xml) by POSTing the xml computed above to login.microsoftonline.com/extSTS.srf
    {body} <- bind-p request-p do
        method: \POST
        body: security-token-request-xml
        uri: \https://login.microsoftonline.com/extSTS.srf

    # jqueryify the xml
    $security-token-xml = cheerio.load body, xml-mode: true

    $faults = $security-token-xml 'S\\:Fault'

    if $faults.length > 0
        reject-p $faults.html!

    else

        # finally, extract the security token from xml using cheerio
        security-token = $security-token-xml 'wsse\\:BinarySecurityToken' .text!

        # POST security token to sharepoint domain to get auth cookies for subsequent requests
        {response} <- bind-p request-p do
            method: \POST
            headers:
                \content-length : security-token.length
                \user-agent : 'Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; WOW64; Trident/5.0)'
            body: security-token
            uri: "#{endpoint}/_forms/default.aspx?wa=wsignin1.0"
            follows: false

        auth-cookies = response.headers[\set-cookie] 
            |> map (cookie) -> cookie.split \; .0
            |> Str.join \;

        # authenticated-request :: object -> p a
        authenticated-request = ({headers}:request-options?) ->
            {body} <- bind-p request-p do 
                {} <<< request-options <<< 
                    headers: {} <<< (headers ? {}) <<< 
                        \accept : \application/json
                        cookie: auth-cookies
            json = JSON.parse body
            if json[\odata.error] then reject-p json[\odata.error] else return-p json

        # :: -> p [{guid :: String, title :: String}]
        get-lists: ->
            {value} <- bind-p authenticated-request do
                uri: "#{endpoint}/_api/lists"

            value |> map ({Id, Title}?) ->
                guid: Id
                title: Title

        # :: String -> p [Item]
        get-list-items: (list-name, odata-query) ->

            # fetch the fields for the given list
            {value} <- bind-p authenticated-request do
                uri: "#{endpoint}/_api/lists/getbytitle('#{list-name}')/fields"

            # columns is a collection of visible columns :: {entity-poperty-name :: String, title :: String}
            # entity-property-name is an internal name of a column which is used in odata queries / result
            columns = value
                |> reject (?.Hidden)
                |> map ({EntityPropertyName, Title}?) ->
                    entity-property-name: EntityPropertyName
                    title: Title

            # convert odata query object to querystring & replace column names with corresponding entity property name
            odata-querystring =  columns |> fold do 
                (memo, {entity-property-name, title}) ->
                    memo.replace do 
                        new RegExp title, \g
                        entity-property-name
                querystring.stringify odata-query

            # query sharepoint list & fetch all the items
            {value} <- bind-p authenticated-request do
                uri: "#{endpoint}/_api/lists/getbytitle('#{list-name}')/items?#{odata-querystring}"

            # convert entity-property-name to the corresponding human readable column name
            value |> map (item) ->
                item 
                    |> obj-to-pairs
                    |> map ([key, value]) ->
                        {title}:column? = columns |> find (.entity-property-name == key)
                        [title, value]
                    |> filter ([key]) -> \string == typeof key
                    |> pairs-to-obj