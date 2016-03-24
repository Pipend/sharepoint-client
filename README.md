# sharepoint-client

A simple Promise based node.js REST client for SharePoint online

## Install
`npm install sharepoint-client`

## Usage (livescript)
```LiveScript
client <- require (\sharepoint-client) endpoint, user, password .then _
[{name}] <- client.get-lists! .then _
get-list-items name
```

## Usage (javascript)

```javascript
require("sharepoint-client")(endPoint, username, password)
    .then((client) => {
        client.getLists().then((lists) => {
            client.getListItems(lists[0].name)
        })
    })
```
