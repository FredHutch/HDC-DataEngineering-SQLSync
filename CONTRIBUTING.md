# Contributing to the SQL Sync Utility

First of all, welcome! We're excited that you'd like to contribute. How would you like to help?

* [I'd like to report a bug](#how-to-report-bugs)
* [I'd like someone else to build something](#how-to-request-features)
* [I'd like to build a new feature myself](#how-to-build-features-yourself)

Everyone here is expected to abide by the [Contributor Covenant Code of Conduct](#the-contributor-covenant-code-of-conduct).


## How to Report Bugs

Check out the [Github issues list]. Search for what you're interested in - there may already be an issue for it. 

Make sure to search through [closed issues list], too, because others have may already encountered the bug.

If you can't find a similar issue, go ahead and open your own. Include as much detail as you can - what you're seeing now, and what you'd expect to see instead.

## How to Request Features

Open source is community-built software. Anyone is welcome to build things that would help make their job easier.

Open source isn't free development, though. Working on these scripts is hard work: they have to work on case-sensitive instances, and on all supported versions of SQL Server (currently 2008 through 2016.) If you just waltz in and say, "Someone please bake me a cake," you're probably not going to get a cake.

If you want something, you're going to either need to build it yourself, or convince someone else to devote their free time to your feature request. You can do that by sponsoring development (offering to hire a developer to build it for you), or getting people excited enough that they volunteer to build it for you.

Here's how to get started.

## How to Build Features Yourself

When you're ready to start coding, discuss it with the community. Check the [Github issues list] and the [closed issues list] because folks may have tried it in the past, or the community may have decided it's not a good fit for these tools.

If you can't find it in an existing issue, open a new Github issue for it. Outline what you'd like to do, why you'd like to do it, and optionally, how you'd think about coding it. This just helps make sure other users agree that it's a good idea to add to these tools. Other folks will respond to the idea, and if you get a warm reception, go for it!

After your Github issue has gotten good responses from a couple of volunteers who are willing to test your work, get started by forking the project and working on your own server. The Github instructions are below - it isn't exactly easy, and we totally understand if you're not up for it. Thing is, we can't take code contributions via text requests - Github makes it way easier for us to compare your work versus the changes other people have made, and merge them all together.

Note that if you're not ready to get started coding in the next week, or if you think you can't finish the feature in the next 30 days, you probably don't want to bother opening an issue. You're only going to feel guilty over not making progress, because we'll keep checking in with you to see how it's going. We don't want to have stale "someday I'll build that" issues in the list - we want to keep the open issues list easy to scan for folks who are trying to troubleshoot bugs and feature requests.

### Contributing T-SQL Code: Git Flow for Pull Requests

<a name="git-flow"></a>

1. [Fork] the project, clone your fork, and configure the remotes:

   ```bash
   # Clone your fork of the repo into the current directory
   git clone git@github.com:<YOUR_USERNAME>/HDC-DataEngineering-SQLSync.git
   # Navigate to the newly cloned directory
   cd HDC-DataEngineering-SQLSync
   # Assign the original repo to a remote called "upstream"
   git remote add upstream https://github.com/FredHutch/HDC-DataEngineering-SQLSync/
   ```

2. If you cloned a while ago, get the latest changes from upstream:

   ```bash
   git checkout master
   git pull upstream master
   ```

3. Create a new topic branch (off the main project development branch) to
   contain your feature, change, or fix:

   ```bash
   git checkout -b <topic-branch-name>
   ```

4. Commit your changes in logical chunks. Please adhere to these [git commit message guidelines]
   or your code is unlikely be merged into the main project. Use Git's [interactive rebase]
   feature to tidy up your commits before making them public.

5. Locally merge (or rebase) the upstream development branch into your topic branch:

   ```bash
   git pull [--rebase] upstream master
   ```

6. Push your topic branch up to your fork:

   ```bash
   git push origin <topic-branch-name>
   ```

7. [Open a Pull Request] with a clear title and description.

**IMPORTANT**: By submitting a patch, you agree to allow the project owner to license your work under the Apache 2.0 [LICENSE]

## The Contributor Covenant Code of Conduct

### Our Pledge

In the interest of fostering an open and welcoming environment, we as contributors and maintainers pledge to making participation in our project and our community a harassment-free experience for everyone, regardless of age, body size, disability, ethnicity, gender identity and expression, level of experience, nationality, personal appearance, race, religion, or sexual identity and orientation.

### Our Standards

Examples of behavior that contributes to creating a positive environment
include:

* Using welcoming and inclusive language
* Being respectful of differing viewpoints and experiences
* Gracefully accepting constructive criticism
* Focusing on what is best for the community
* Showing empathy towards other community members

Examples of unacceptable behavior by participants include:

* The use of sexualized language or imagery and unwelcome sexual attention or
  advances
* Trolling, insulting/derogatory comments, and personal or political attacks
* Public or private harassment
* Publishing others' private information, such as a physical or electronic
  address, without explicit permission
* Other conduct which could reasonably be considered inappropriate in a
  professional setting

### Our Responsibilities

Project maintainers are responsible for clarifying the standards of acceptable behavior and are expected to take appropriate and fair corrective action in response to any instances of unacceptable behavior.

Project maintainers have the right and responsibility to remove, edit, or reject comments, commits, code, wiki edits, issues, and other contributions that are not aligned to this Code of Conduct, or to ban temporarily or permanently any contributor for other behaviors that they deem inappropriate, threatening, offensive, or harmful.

### Scope

This Code of Conduct applies both within project spaces and in public spaces when an individual is representing the project or its community. Examples of representing a project or community include using an official project e-mail address, posting via an official social media account, or acting as an appointed representative at an online or offline event. Representation of a project may be further defined and clarified by project maintainers.

### Enforcement

Instances of abusive, harassing, or otherwise unacceptable behavior may be reported by contacting the project team at HDC@FredHutch.org. All complaints will be reviewed and investigated and will result in a response that is deemed necessary and appropriate to the circumstances. The project team is obligated to maintain confidentiality with regard to the reporter of an incident. Further details of specific enforcement policies may be posted separately.

Project maintainers who do not follow or enforce the Code of Conduct in good faith may face temporary or permanent repercussions as determined by other members of the project's leadership.

### Attribution

This Code of Conduct is adapted from the [Contributor Covenant][homepage], version 1.4,
available at [http://contributor-covenant.org/version/1/4][version]



[homepage]: http://contributor-covenant.org
[version]: http://contributor-covenant.org/version/1/4/
[Github issues list]:https://github.com/FredHutch/HDC-DataEngineering-SQLSync/issues
[closed issues list]:https://github.com/FredHutch/HDC-DataEngineering-SQLSync/issues?q=is%3Aissue+is%3Aclosed
[Fork]:https://help.github.com/articles/fork-a-repo/
[git commit message guidelines]:http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html
[interactive rebase]:https://help.github.com/articles/about-git-rebase/
[Open a Pull Request]:https://help.github.com/articles/about-pull-requests/
[LICENSE]:/LICENSE