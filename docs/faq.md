# Frequently Asked Questions (FAQ)


**Does column order matter?**

No! Never!

**What indexes are useful?**

That's a question with a long answer. Check out the [Type-1](/docs/type-1.md) and [Type-2](/docs/type-2.md) pages.

**Can the same source table be used for multiple targets?**

Yes. However, you should make sure that the 

**Can multiple sources be used to load the same target table?**

No

**Can a source table be loaded if it has no update-date column?**

Not at the moment. This could be added if it's needed.

**Can you use a view as the source?**

Sure.

**Can you use a view as the target**

Sure. 

**What types of processing are supported?**

Currently there is support only for Type-1 (non-deleting). 

The groundwork has been laid for type-2 tables but it isn't supported yet. That's the [DiffTable](/DiffTable.sql) stored procedure. 

**Can a table be sync'd if it doesn't have a primary key?**

Sort of. You don't need a primary key index defined in the source, but you must configure one in the SyncConfig table.

**What happens if there are duplicates?**

If there are duplicate entries for a single PK and source update-date value, then the sync will fail for that table.

**What about case sensitivity in data?**

Right now case-sensitive changes in the data are ignored, so if you change 'this is sparta' to 'THIS IS SPARTA', the diff code will ignore the change. It's on the roadmap of things to change

**What about case sensitive SQL instances?**

This is not supported at all yet. Feel free to contribute if this is something you want to add.


