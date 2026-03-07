pub const c = @cImport({
    @cInclude("clay.h");
});

pub const Clay_Context = c.Clay_Context;
pub const Clay_Arena = c.Clay_Arena;
pub const Clay_Dimensions = c.Clay_Dimensions;
pub const Clay_Vector2 = c.Clay_Vector2;
pub const Clay_ErrorData = c.Clay_ErrorData;
pub const Clay_ErrorHandler = c.Clay_ErrorHandler;
pub const Clay_RenderCommandArray = c.Clay_RenderCommandArray;

pub const Clay_MinMemorySize = c.Clay_MinMemorySize;
pub const Clay_Initialize = c.Clay_Initialize;
pub const Clay_SetPointerState = c.Clay_SetPointerState;
pub const Clay_BeginLayout = c.Clay_BeginLayout;
pub const Clay_EndLayout = c.Clay_EndLayout;
