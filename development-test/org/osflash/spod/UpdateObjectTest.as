package org.osflash.spod
{
	import org.osflash.logger.logs.debug;
	import org.osflash.logger.logs.error;
	import org.osflash.spod.errors.SpodErrorEvent;
	import org.osflash.spod.support.user.User;

	import flash.display.Sprite;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.filesystem.File;
	
	[SWF(backgroundColor="#FFFFFF", frameRate="31", width="1280", height="720")]
	public class UpdateObjectTest extends Sprite
	{
		
		private static const sessionName : String = "session.db"; 
		
		protected var resource : File;
		
		public function UpdateObjectTest()
		{
			stage.scaleMode = StageScaleMode.NO_SCALE;
			stage.align = StageAlign.TOP_LEFT;
						
			const storage : File = File.applicationStorageDirectory.resolvePath(sessionName);
			resource = storage;
			
			const manager : SpodManager = new SpodManager();
			manager.openSignal.add(handleOpenSignal);
			manager.errorSignal.add(handleErrorSignal);
			manager.open(resource, true);
		}
		
		protected function handleOpenSignal(database : SpodDatabase) : void
		{
			database.createTableSignal.add(handleCreatedSignal);
			database.createTable(User);
		}
		
		protected function handleCreatedSignal(table : SpodTable) : void
		{
			table.insertSignal.add(handleInsertSignal);
			table.insert(new User("Fred - " + Math.random()));
		}
		
		protected function handleInsertSignal(object : SpodObject) : void
		{
			object.tableRow.updateSignal.add(handleRowUpdateSignal);
			
			const user : User = object as User;
			user.updateSignal.add(handleUserUpdateSignal);
		 	user.name = "Jim - " + Math.random();
		 	user.update();
		}
		
		protected function handleRowUpdateSignal(object : SpodObject) : void
		{
			const user : User = object as User;
			
			debug("I am from the row ", user.name);
		}
		
		protected function handleUserUpdateSignal(object : SpodObject) : void
		{
			const user : User = object as User;
			
			debug("I am from the user ", user.name);
		}
			
		protected function handleErrorSignal(event : SpodErrorEvent) : void
		{
			error(event.event.error);
		}
	}
}
