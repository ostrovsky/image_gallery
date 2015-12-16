This is an excercise in Elixir programming.  It provides an image gallery, which
receives images attached in e-mails (via mailgun.com), resizes them to fit
400x300px, and displays them based on selected receiver and/or sender.

Build using standard Elixir build system:

``` bash
mix
```

Start using standard Elixir command:

``` bash
iex -S mix
```

To get the whole system working you need to setup a mailgun.com routing
to forward all e-mails to the machine where you deployed, for example: when
deployed on test.com the mailgun.com routing rule would be:

``` bash
forward("http://test.com:8080/post")
```

To access the gallery you point your browser to:

```bash
http://test.com:8080/gallery
```
