/// Copyable shell examples for the current listening model. Keep stored IDs stable.
public enum AgentExamples {
    public static let commands = """
    onde music list focus
    onde music list relax
    onde music defaults
    onde music default focus ambre
    onde music default relax velours
    onde music default meditation rive

    onde focus --launch
    onde music play sanctuaire
    onde music play velours --mode meditation
    onde pause
    onde play
    onde stop

    onde music volume 0.65
    onde background white 0.15
    onde background off
    onde settings startFadeSeconds 8
    onde generate transition 10

    onde timer markers 10,20,30
    onde settings chimeVolume 0.2
    onde mix save 'My focus mix'
    onde mix load 'My focus mix'

    onde status
    onde watch
    onde schema
    """
}
