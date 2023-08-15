#!/usr/bin/perl

BEGIN {
  if ($ARGV[0] eq "--zabbix-test-run"){
    print "ZABBIX TEST OK";
    exit;
  }
}

no warnings 'redefine';
no strict 'refs';

use Mojolicious::Lite -signatures;
use Mojo::UserAgent;
use Data::Dumper;

my $ua  = Mojo::UserAgent->new;

my $url_teams_webhook = "https://atea.webhook.office.com/webhookb2/8e8349e4-1a21-4d1f-a72d-fcca57753c73@65f51067-7d65-4aa9-b996-4cc43a0d7111/IncomingWebhook/fd039b014b3f466d8c1d895d68d9e8e7/4c38e6fe-9b62-458d-a65c-d5c966487eee";


my %json2 = (
   "type" => "message",
   "attachments" => [
      {
         "contentType" => "application/vnd.microsoft.card.adaptive",
         "contentUrl" => "null",
         "content" => {
            "\$schema" => "http => //adaptivecards.io/schemas/adaptive-card.json",
            "type" => "AdaptiveCard",
            "version" => "1.2",
            "body" => [
              {
                "type" =>  "TextBlock",
                "text" =>  "For Samples and Templates, see [https => //adaptivecards.io/samples](https => //adaptivecards.io/samples)",
              },
            ],
              "target"  => "https://zabbix.kjartanohr.no/zabbix/",
         },
      },
   ],
);

my %json3 = (
   "type" => "message",
   "attachments" => [

    "title" => "Publish Adaptive Card Schema",
    "description" => "Now that we have defined the main rules and features of the format, we need to produce a schema and publish it to GitHub. The schema will be the starting point of our reference documentation.",
    "creator" => {
        "name" => "Matt Hidinger",
        "profileImage" => "https =>//pbs.twimg.com/profile_images/3647943215/d7f12830b3c17a5a9e4afcc370e3a37e_400x400.jpeg"
    },
    "createdUtc" => "2017-02-14T06 =>08 =>39Z",
    "viewUrl" => "https =>//adaptivecards.io",
    "properties" => [
        { "key" => "Board", "value" => "Adaptive Cards" },
        { "key" => "List", "value" => "Backlog" },
        { "key" => "Assigned to", "value" => "Matt Hidinger" },
        { "key" => "Due date", "value" => "Not set" }
    ],
  ],
);

my %json = (
  "text" => "test alarm",
);

my %template = (
    "type" => "AdaptiveCard",
    "version" => "1.0",
    "body" => [
        {
            "type" => "ColumnSet",
            "style" => "accent",
            "bleed" => "true",
            "columns" => [
                {
                    "type" => "Column",
                    "width" => "auto",
                    "items" => [
                        {
                            "type" => "Image",
                            "url" => "\${photo}",
                            "altText" => "Profile picture",
                            "size" => "Small",
                            "style" => "Person"
                        }
                    ]
                },
                {
                    "type" => "Column",
                    "width" => "stretch",
                    "items" => [
                        {
                            "type" => "TextBlock",
                            "text" => "Hi \${name}!",
                            "size" => "Medium"
                        },
                        {
                            "type" => "TextBlock",
                            "text" => "Here's a bit about your org...",
                            "spacing" => "None"
                        }
                    ]
                }
            ]
        },
        {
            "type" => "TextBlock",
            "text" => "Your manager is => **\${manager.name}**"
        },
        {
            "type" => "TextBlock",
            "text" => "Your peers are =>"
        },
        {
            "type" => "FactSet",
            "facts" => [
                {
                    "\$data" => "\${peers}",
                    "title" => "\${name}",
                    "value" => "\${title}"
                }
            ]
        }
    ]
);

my %card = (
    "name" => "Matt",
    "photo" => "https =>//pbs.twimg.com/profile_images/3647943215/d7f12830b3c17a5a9e4afcc370e3a37e_400x400.jpeg",
    "manager" => {
        "name" => "Thomas",
        "title" => "PM Lead"
    },
    "peers" => [
        {
            "name" => "Lei",
            "title" => "Sr Program Manager"
        },
        {
            "name" => "Andrew",
            "title" => "Program Manager II"
        },
        {
            "name" => "Mary Anne",
            "title" => "Program Manager"
        }
    ]
);

my %json4 = (
  "template" => %template,
  "card"    => %card,
);

#contentType: "application/vnd.microsoft.card.adaptive",
my %json5 = (
            type => "AdaptiveCard",
            speak => "<s>Your  meeting about \"Adaptive Card design session\"<break strength='weak'/> is starting at 12 =>30pm</s><s>Do you want to snooze <break strength='weak'/> or do you want to send a late notification to the attendees?</s>",
               body => [
                    {
                        "type" => "TextBlock",
                        "text" => "Adaptive Card design session",
                        "size" => "large",
                        "weight" => "bolder"
                    },
                    {
                        "type" => "TextBlock",
                        "text" => "Conf Room 112/3377 (10)"
                    },
                    {
                        "type" => "TextBlock",
                        "text" => "12 =>30 PM - 1 =>30 PM"
                    },
                    {
                        "type" => "TextBlock",
                        "text" => "Snooze for"
                    },
                    {
                        "type" => "Input.ChoiceSet",
                        "id" => "snooze",
                        "style" =>"compact",
                        "choices" => [
                            {
                                "title" => "5 minutes",
                                "value" => "5",
                                "isSelected" => "true"
                            },
                            {
                                "title" => "15 minutes",
                                "value" => "15"
                            },
                            {
                                "title" => "30 minutes",
                                "value" => "30"
                            }
                        ]
                    }
                ],
                "actions" => [
                    {
                        "type" => "Action.OpenUrl",
                        "method" => "POST",
                        "url" => "http://foo.com",
                        "title" => "Snooze"
                    },
                    {
                        "type" => "Action.OpenUrl",
                        "method" => "POST",
                        "url" => "http://foo.com",
                        "title" => "I'll be late"
                    },
                    {
                        "type" => "Action.OpenUrl",
                        "method" => "POST",
                        "url" => "http://foo.com",
                        "title" => "Dismiss"
                    }
                ]
);

my %json6 = (
    "type" => "AdaptiveCard",
    "body" => [
        {
            "type" => "TextBlock",
            "size" => "Medium",
            "weight" => "Bolder",
            "text" => "Zabbix",
            "wrap" => "true",
        },
        {
            "type" => "ColumnSet",
            "columns" => [
                {
                    "type" => "Column",
                    "items" => [
                        {
                            "type" => "Image",
                            "style" => "Person",
                            "url" => "https =>//zabbix.kjartanohr.no/zabbix/logo.png",
                            "size" => "Small"
                        }
                    ],
                    "width" => "auto"
                },
                {
                    "type" => "Column",
                    "items" => [
                        {
                            "type" => "TextBlock",
                            "weight" => "Bolder",
                            "text" => "Kjartan",
                            "wrap" => "true",
                        },
                        {
                            "type" => "TextBlock",
                            "spacing" => "None",
                            "text" => "kjartan",
                            "isSubtle" => "true",
                            "wrap" => "true",
                        }
                    ],
                    "width" => "stretch"
                }
            ]
        },
        {
            "type" => "TextBlock",
            "text" => "Beksrivlse av alarm. med litt mer info",
            "wrap" => "true",
        },
        {
            "type" => "FactSet",
            "facts" => [
                {
                    "\$data" => "Data",
                    "title" => "Alarm nivå",
                    "value" => "Critical"
                }
            ]
        }
    ],
    "actions" => [
        {
            "type" => "Action.ShowCard",
            "title" => "Godkjenn alarm",
            "card" => {
                "type" => "AdaptiveCard",
                "body" => [
                    {
                        "type" => "Input.Date",
                        "id" => "dueDate"
                    },
                    {
                        "type" => "Input.Text",
                        "id" => "comment",
                        "placeholder" => "Add a comment",
                        "isMultiline" => "true",
                    }
                ],
                "actions" => [
                    {
                        "type" => "Action.Submit",
                        "title" => "OK"
                    }
                ],
                "\$schema" => "http =>//adaptivecards.io/schemas/adaptive-card.json"
            }
        },
        {
            "type" => "Action.OpenUrl",
            "title" => "View",
            "url" => "https://zabbix.kjartanohr.no/zabbix/?submit"
        }
    ],
    "\$schema" => "http =>//adaptivecards.io/schemas/adaptive-card.json",
    "version" => "1.3"


);

#my $tx = $ua->post(
#  $url_teams_webhook,
#  "json" => %json,
#);


my $tx = $ua->post(
  $url_teams_webhook,
  {
    'Accept'        => '*/*', 
    #'Authorization' => $input{'token'},
    'Content-Type'  => 'application/json',
    #'Content-Type'  => 'application/vnd.microsoft.card.adaptive',
  },
    'json'  => \%json2,
);

print "Message: ".$tx->res->message;
print Dumper $tx->result->content();
