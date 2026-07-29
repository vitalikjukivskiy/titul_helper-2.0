namespace CyberPW.Assistant2
{
    internal interface IModulePage
    {
        string Title { get; }
        void OnActivated();
    }
}
